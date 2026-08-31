import { HttpError } from './http';

/**
 * What a caller is allowed to ask the model for.
 *
 * This is the layer that makes a leaked app key survivable. Without it, the
 * proxy is just your Replicate token behind a different URL: anyone holding the
 * key could start runs of the most expensive model on the platform against
 * arbitrary URLs. With it, the worst a thief can do is run *your* model, at
 * *your* scale ceiling, on images they first uploaded through *your* quota.
 *
 * The rule is allow-list, never deny-list: unknown input keys are dropped
 * rather than forwarded, so a new model parameter cannot be smuggled through by
 * someone who reads the upstream docs before you do. That applies per model —
 * see [ModelPolicy] — not once for the whole endpoint.
 */

/**
 * Images must be files this proxy itself uploaded.
 *
 * Replicate would happily fetch any URL given to it. Restricting inputs to
 * `api.replicate.com/v1/files/…` closes that: a caller cannot use your account
 * to pull down a URL of their choosing, and every byte the model reads has
 * already passed this Worker's size check.
 *
 * Checked structurally (scheme + host + exact path depth), not by guessing at
 * the id's character set. An earlier version used a `[A-Za-z0-9_-]+` regex,
 * which broke every real upload the day Replicate started appending the
 * original extension to the id (`…WMy.png`) — a `.` the regex didn't allow.
 * The security property this exists for is host + path shape; the id's own
 * alphabet was never actually load-bearing and isn't validated here.
 */
function isReplicateFileUrl(candidate: string): boolean {
	let url: URL;
	try {
		url = new URL(candidate);
	} catch {
		return false;
	}
	if (url.protocol !== 'https:' || url.hostname !== 'api.replicate.com') return false;
	if (url.search !== '' || url.hash !== '') return false;
	const segments = url.pathname.split('/').filter((s) => s.length > 0);
	return segments.length === 3 && segments[0] === 'v1' && segments[1] === 'files';
}

export interface PredictionRequest {
	version: string;
	input: Record<string, unknown>;
}

/**
 * What each permitted model is allowed to be asked for.
 *
 * The allow-list is now a small set rather than a single string, because the
 * app runs two genuinely different models — an upscaler and a background
 * remover — and they take different inputs. The security property is unchanged
 * and deliberately not relaxed: a version that is not in this list is refused,
 * and each entry rebuilds its own input from scratch, so no key the caller sent
 * reaches Replicate unless this file put it there.
 *
 * `kind` selects the schema. It is not taken from the request — it is looked up
 * from the version, so a caller cannot pair one model's version with another
 * model's (cheaper to validate, more expensive to run) input.
 */
export type ModelKind = 'upscale' | 'background';

export interface ModelPolicy {
	version: string;
	kind: ModelKind;
}

/** The shared first field: every model here takes one image, and only ours. */
function requireImage(fields: Record<string, unknown>): string {
	const image = fields.image;
	if (typeof image !== 'string' || !isReplicateFileUrl(image)) {
		throw new HttpError(400, 'The image must be a file uploaded through this API.');
	}
	return image;
}

/** Real-ESRGAN: image, an integer scale under the ceiling, and a face flag. */
function upscaleInput(fields: Record<string, unknown>, maxScale: number): Record<string, unknown> {
	const image = requireImage(fields);

	const scale = fields.scale;
	if (typeof scale !== 'number' || !Number.isInteger(scale) || scale < 1 || scale > maxScale) {
		throw new HttpError(400, `Scale must be a whole number between 1 and ${maxScale}.`);
	}

	const faceEnhance = fields.face_enhance;
	if (typeof faceEnhance !== 'boolean') {
		throw new HttpError(400, 'face_enhance must be true or false.');
	}

	return { image, scale, face_enhance: faceEnhance };
}

/**
 * Background remover: image, plus the three knobs that decide what comes back.
 *
 * `background_type` is the one worth being strict about. Its schema accepts a
 * path to an image, so forwarding an arbitrary string would hand back exactly
 * the "fetch a URL of the caller's choosing" hole that [isReplicateFileUrl]
 * exists to close. Only the fixed keywords are permitted.
 */
const BACKGROUND_TYPES = new Set(['rgba', 'map', 'green', 'white', 'blur', 'overlay']);

function backgroundInput(fields: Record<string, unknown>): Record<string, unknown> {
	const image = requireImage(fields);

	const format = fields.format;
	if (format !== undefined && format !== 'png' && format !== 'jpg') {
		throw new HttpError(400, 'Format must be png or jpg.');
	}

	const backgroundType = fields.background_type;
	if (backgroundType !== undefined && (typeof backgroundType !== 'string' || !BACKGROUND_TYPES.has(backgroundType))) {
		throw new HttpError(400, 'That background type is not available through this endpoint.');
	}

	const threshold = fields.threshold;
	if (threshold !== undefined && (typeof threshold !== 'number' || !(threshold >= 0 && threshold <= 1))) {
		throw new HttpError(400, 'Threshold must be a number between 0 and 1.');
	}

	const reverse = fields.reverse;
	if (reverse !== undefined && typeof reverse !== 'boolean') {
		throw new HttpError(400, 'reverse must be true or false.');
	}

	return {
		image,
		format: format ?? 'png',
		background_type: backgroundType ?? 'rgba',
		threshold: threshold ?? 0,
		reverse: reverse ?? false,
	};
}

/** Parses and validates a create-prediction body, or throws a 400. */
export function validatePrediction(body: unknown, models: readonly ModelPolicy[], maxScale: number): PredictionRequest {
	if (typeof body !== 'object' || body === null) {
		throw new HttpError(400, 'A JSON body is required.');
	}
	const raw = body as Record<string, unknown>;

	const model = models.find((m) => m.version === raw.version);
	if (!model) {
		// Named explicitly rather than "invalid request": a version mismatch after
		// a model upgrade is a real thing to debug, and this message says so
		// without revealing anything sensitive.
		throw new HttpError(400, 'That model version is not available through this endpoint.');
	}

	const input = raw.input;
	if (typeof input !== 'object' || input === null) {
		throw new HttpError(400, 'An input object is required.');
	}
	const fields = input as Record<string, unknown>;

	// Rebuilt from scratch: only the keys the chosen model's schema names reach
	// Replicate, whatever else the caller sent.
	return {
		version: model.version,
		input: model.kind === 'upscale' ? upscaleInput(fields, maxScale) : backgroundInput(fields),
	};
}

/** The models this deployment permits, read from configuration. */
export function modelsFrom(env: { ALLOWED_MODEL_VERSION: string; BACKGROUND_MODEL_VERSION?: string }): ModelPolicy[] {
	const models: ModelPolicy[] = [{ version: env.ALLOWED_MODEL_VERSION, kind: 'upscale' }];
	// Optional, so a deployment that has not been reconfigured yet keeps
	// working with the upscaler alone rather than failing to start.
	if (env.BACKGROUND_MODEL_VERSION) {
		models.push({ version: env.BACKGROUND_MODEL_VERSION, kind: 'background' });
	}
	return models;
}

/** Prediction ids as they appear in Replicate's URLs. */
const PREDICTION_ID_PATTERN = /^[A-Za-z0-9]{1,64}$/;

export function validatePredictionId(id: string): string {
	if (!PREDICTION_ID_PATTERN.test(id)) {
		throw new HttpError(400, 'Invalid prediction id.');
	}
	return id;
}

/**
 * Only the fields the app needs are passed back.
 *
 * Replicate's prediction object also carries `urls`, `logs`, `metrics` and
 * account-shaped metadata. None of it is used by the client, and forwarding it
 * would expose more of your account's internals than an API for a photo app
 * needs to.
 */
export function projectPrediction(upstream: unknown): Record<string, unknown> {
	const raw = (typeof upstream === 'object' && upstream !== null ? upstream : {}) as Record<string, unknown>;
	return {
		id: raw.id ?? null,
		status: raw.status ?? 'failed',
		output: raw.output ?? null,
		error: raw.error ?? null,
	};
}

/**
 * The upload reply, reduced to the one URL the client sends back to us.
 *
 * A `urls.get` shape is kept so the existing Flutter client parses proxy and
 * direct-API responses identically.
 */
export function projectFile(upstream: unknown): Record<string, unknown> {
	const raw = (typeof upstream === 'object' && upstream !== null ? upstream : {}) as Record<string, unknown>;
	const urls = (typeof raw.urls === 'object' && raw.urls !== null ? raw.urls : {}) as Record<string, unknown>;
	const get = urls.get;
	if (typeof get !== 'string' || !isReplicateFileUrl(get)) {
		throw new HttpError(502, 'The upload service returned an unexpected reply.');
	}
	return { id: raw.id ?? null, urls: { get } };
}
