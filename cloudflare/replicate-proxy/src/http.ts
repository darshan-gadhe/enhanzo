/**
 * Response helpers.
 *
 * Every error the proxy returns uses Replicate's own `detail` field, so the
 * Flutter client's existing parser surfaces proxy errors and upstream errors
 * through exactly the same path.
 */

/** A failure with the status the client should see. */
export class HttpError extends Error {
	constructor(
		readonly status: number,
		message: string,
	) {
		super(message);
		this.name = 'HttpError';
	}
}

export function json(body: unknown, status = 200, extraHeaders?: HeadersInit): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: {
			'content-type': 'application/json; charset=utf-8',
			// This is an API for a mobile app, not a browser. No CORS headers are
			// sent, so a page on someone else's origin cannot read the responses
			// even if it learns the URL.
			'cache-control': 'no-store',
			'x-content-type-options': 'nosniff',
			...(extraHeaders ?? {}),
		},
	});
}

export function error(status: number, detail: string, extraHeaders?: HeadersInit): Response {
	return json({ detail }, status, extraHeaders);
}

/**
 * Structured request log.
 *
 * Deliberately narrow: no token, no headers, no image URLs, and the device id
 * truncated. Enough to spot abuse and debug a failure, not enough to be a
 * privacy problem if the logs are shared.
 */
export function logRequest(fields: {
	path: string;
	method: string;
	status: number;
	ms: number;
	device?: string;
	reason?: string;
}): void {
	const line = {
		...fields,
		device: fields.device ? `${fields.device.slice(0, 8)}…` : undefined,
	};
	if (fields.status >= 500) {
		console.error(JSON.stringify(line));
	} else if (fields.status >= 400) {
		console.warn(JSON.stringify(line));
	} else {
		console.log(JSON.stringify(line));
	}
}
