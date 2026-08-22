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
 * someone who reads the upstream docs before you do.
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
	input: {
		image: string;
		scale: number;
		face_enhance: boolean;
	};
}

/** Parses and validates a create-prediction body, or throws a 400. */
export function validatePrediction(body: unknown, allowedVersion: string, maxScale: number): PredictionRequest {
	if (typeof body !== 'object' || body === null) {
		throw new HttpError(400, 'A JSON body is required.');
	}
	const raw = body as Record<string, unknown>;

	if (raw.version !== allowedVersion) {
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

	const image = fields.image;
	if (typeof image !== 'string' || !isReplicateFileUrl(image)) {
		throw new HttpError(400, 'The image must be a file uploaded through this API.');
	}

	const scale = fields.scale;
	if (typeof scale !== 'number' || !Number.isInteger(scale) || scale < 1 || scale > maxScale) {
		throw new HttpError(400, `Scale must be a whole number between 1 and ${maxScale}.`);
	}

	const faceEnhance = fields.face_enhance;
	if (typeof faceEnhance !== 'boolean') {
		throw new HttpError(400, 'face_enhance must be true or false.');
	}

	// Rebuilt from scratch: only these three keys reach Replicate, whatever else
	// the caller sent.
	return { version: allowedVersion, input: { image, scale, face_enhance: faceEnhance } };
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
