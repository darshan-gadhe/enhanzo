import { authenticate, type Caller } from './auth';
import { error, HttpError, json, logRequest } from './http';
import { checkDailyQuota, enforceRateLimit, recordUsage } from './limits';
import { modelsFrom, projectFile, projectPrediction, validatePrediction, validatePredictionId } from './validate';

/**
 * The Replicate proxy.
 *
 * The app holds no Replicate token. It calls this Worker, the Worker attaches
 * the token from its secret store, and only a reduced view of the reply comes
 * back. The token exists in exactly one place — Cloudflare's encrypted secret
 * storage — and is never logged, echoed, or returned.
 *
 * Routes (deliberately the same shapes Replicate uses, so the client needs no
 * separate code path for proxy vs. direct):
 *
 *   GET  /health                        — unauthenticated liveness check
 *   POST /v1/files                      — upload the photo to enhance
 *   POST /v1/predictions                — start a run (validated + quota'd)
 *   GET  /v1/predictions/:id            — poll one
 *   POST /v1/predictions/:id/cancel     — stop one
 *
 * Everything but /health requires `X-App-Key` and `X-Device-Id`.
 */

const UPSTREAM = 'https://api.replicate.com';

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		const started = Date.now();
		const url = new URL(request.url);
		let caller: Caller | undefined;

		try {
			if (url.pathname === '/health') {
				return json({ status: 'ok' });
			}

			// Requests carrying an Origin come from a browser, which is not a client
			// this API has. No CORS headers are ever sent either, so a page cannot
			// read a response even if it manages to send one.
			if (request.headers.has('origin')) {
				throw new HttpError(403, 'Not available from a browser.');
			}

			caller = await authenticate(request, env.APP_KEY);
			const response = await route(request, url, env, ctx, caller);
			logRequest({
				path: url.pathname,
				method: request.method,
				status: response.status,
				ms: Date.now() - started,
				device: caller.device,
			});
			return response;
		} catch (thrown) {
			const status = thrown instanceof HttpError ? thrown.status : 500;
			const detail =
				thrown instanceof HttpError
					? thrown.message
					: // Never surface an internal message: it can name upstream hosts and
						// stack frames. The real one goes to the logs instead.
						'The request could not be completed.';
			if (!(thrown instanceof HttpError)) {
				console.error(
					JSON.stringify({
						path: url.pathname,
						message: thrown instanceof Error ? thrown.message : String(thrown),
					}),
				);
			}
			logRequest({
				path: url.pathname,
				method: request.method,
				status,
				ms: Date.now() - started,
				device: caller?.device,
				reason: detail,
			});
			return error(status, detail);
		}
	},
} satisfies ExportedHandler<Env>;

async function route(request: Request, url: URL, env: Env, ctx: ExecutionContext, caller: Caller): Promise<Response> {
	const path = url.pathname;

	if (path === '/v1/files' && request.method === 'POST') {
		return uploadFile(request, env, caller);
	}
	if (path === '/v1/predictions' && request.method === 'POST') {
		return createPrediction(request, env, ctx, caller);
	}

	const predictionMatch = /^\/v1\/predictions\/([^/]+)(\/cancel)?$/.exec(path);
	if (predictionMatch) {
		const id = validatePredictionId(predictionMatch[1]);
		const isCancel = predictionMatch[2] === '/cancel';
		if (isCancel && request.method === 'POST') {
			return cancelPrediction(id, env, caller);
		}
		if (!isCancel && request.method === 'GET') {
			return getPrediction(id, env, caller);
		}
	}

	throw new HttpError(404, 'Not found.');
}

/** Headers for a call to Replicate. The token is attached here and nowhere else. */
function upstreamHeaders(env: Env, extra?: Record<string, string>): Headers {
	const headers = new Headers(extra);
	headers.set('authorization', `Bearer ${env.REPLICATE_API_TOKEN}`);
	headers.set('user-agent', 'enhanzo-replicate-proxy/1.0');
	return headers;
}

/**
 * Streams the photo through to Replicate's Files API.
 *
 * The body is passed as a stream rather than buffered: a Worker has 128 MB of
 * memory, and reading a multi-megabyte upload into a string to forward it is
 * the classic way to lose that. Size is enforced from Content-Length *before*
 * any bytes are relayed.
 */
async function uploadFile(request: Request, env: Env, caller: Caller): Promise<Response> {
	await enforceRateLimit(env.GENERAL_LIMITER, `upload:${caller.device}`);

	const maxBytes = Number.parseInt(env.MAX_UPLOAD_BYTES, 10);
	const declared = Number.parseInt(request.headers.get('content-length') ?? '', 10);
	if (!Number.isFinite(declared)) {
		// Without a declared length there is nothing to check before streaming, so
		// the request is refused rather than trusted.
		throw new HttpError(411, 'A Content-Length header is required.');
	}
	if (declared > maxBytes) {
		throw new HttpError(413, `Images must be smaller than ${Math.floor(maxBytes / (1024 * 1024))} MB.`);
	}

	const contentType = request.headers.get('content-type') ?? '';
	if (!contentType.startsWith('multipart/form-data')) {
		throw new HttpError(415, 'Uploads must be multipart/form-data.');
	}

	const upstream = await fetch(`${UPSTREAM}/v1/files`, {
		method: 'POST',
		headers: upstreamHeaders(env, { 'content-type': contentType, 'content-length': String(declared) }),
		body: request.body,
	});

	const body = await upstream.json().catch(() => null);
	if (!upstream.ok) {
		throw new HttpError(upstream.status === 401 ? 502 : upstream.status, detailFrom(body, 'The upload failed.'));
	}
	return json(projectFile(body), 201);
}

/**
 * Starts a run — the only endpoint that spends money, and so the only one that
 * carries the tight rate limit and the daily quota.
 */
async function createPrediction(request: Request, env: Env, ctx: ExecutionContext, caller: Caller): Promise<Response> {
	await enforceRateLimit(env.PREDICTION_LIMITER, `predict:${caller.device}`);

	const quota = Number.parseInt(env.DAILY_PREDICTION_QUOTA, 10);
	const { used, key } = await checkDailyQuota(env.QUOTA, caller.device, quota);

	const body = await request.json().catch(() => null);
	const validated = validatePrediction(body, modelsFrom(env), Number.parseInt(env.MAX_SCALE, 10));

	// `Prefer: wait` lets a short run answer on the first call. The client's
	// value is not trusted through: it is re-issued here, capped, so nobody can
	// pin a Worker open for an arbitrary time.
	const prefer = parsePreferWait(request.headers.get('prefer'));

	const upstream = await fetch(`${UPSTREAM}/v1/predictions`, {
		method: 'POST',
		headers: upstreamHeaders(env, {
			'content-type': 'application/json',
			...(prefer ? { prefer: `wait=${prefer}` } : {}),
		}),
		body: JSON.stringify(validated),
	});

	const payload = await upstream.json().catch(() => null);
	if (!upstream.ok) {
		throw new HttpError(upstream.status === 401 ? 502 : upstream.status, detailFrom(payload, 'The model could not be started.'));
	}

	// Counted only once the run actually started, and off the response path: the
	// user should not wait on a KV write to see their prediction.
	ctx.waitUntil(recordUsage(env.QUOTA, key, used));

	return json(projectPrediction(payload), 201, { 'x-quota-remaining': String(Math.max(0, quota - used - 1)) });
}

async function getPrediction(id: string, env: Env, caller: Caller): Promise<Response> {
	await enforceRateLimit(env.GENERAL_LIMITER, `poll:${caller.device}`);

	const upstream = await fetch(`${UPSTREAM}/v1/predictions/${id}`, {
		method: 'GET',
		headers: upstreamHeaders(env),
	});
	const payload = await upstream.json().catch(() => null);
	if (!upstream.ok) {
		throw new HttpError(upstream.status === 401 ? 502 : upstream.status, detailFrom(payload, 'The prediction could not be read.'));
	}
	return json(projectPrediction(payload));
}

async function cancelPrediction(id: string, env: Env, caller: Caller): Promise<Response> {
	await enforceRateLimit(env.GENERAL_LIMITER, `cancel:${caller.device}`);

	const upstream = await fetch(`${UPSTREAM}/v1/predictions/${id}/cancel`, {
		method: 'POST',
		headers: upstreamHeaders(env),
	});
	// A cancel that arrives after the run finished is not worth an error: the
	// client's intent — stop spending on this — is satisfied either way.
	if (!upstream.ok && upstream.status !== 404 && upstream.status !== 409) {
		throw new HttpError(502, 'The prediction could not be cancelled.');
	}
	return json({ status: 'canceled' });
}

/** Reads Replicate's own error text, falling back to ours. */
function detailFrom(body: unknown, fallback: string): string {
	if (typeof body === 'object' && body !== null) {
		const detail = (body as Record<string, unknown>).detail;
		if (typeof detail === 'string' && detail.length > 0 && detail.length < 300) return detail;
	}
	return fallback;
}

/** Seconds to hold the upstream request open, capped at 60. */
function parsePreferWait(header: string | null): number | null {
	if (header === null) return null;
	const match = /^wait=(\d{1,3})$/.exec(header.trim());
	if (!match) return null;
	return Math.min(Number.parseInt(match[1], 10), 60);
}
