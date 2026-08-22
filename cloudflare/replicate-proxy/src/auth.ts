import { HttpError } from './http';

/**
 * Who is allowed to call this proxy.
 *
 * ## What this can and cannot do
 *
 * The app key below is a shared secret compiled into the mobile binary. Anyone
 * willing to unpack an APK can read it — that is true of *any* static
 * credential in a distributed app, and no amount of obfuscation changes it.
 *
 * So the key is not the security boundary; it is the first of several layers:
 *
 * 1. **App key** — stops opportunistic use by anyone who merely learns the URL.
 * 2. **Rate limits and a daily quota** (`limits.ts`) — bound what a stolen key
 *    can cost you before you notice.
 * 3. **Input validation** (`validate.ts`) — the layer that actually matters. A
 *    stolen key can only run one pinned model, at a bounded scale, on an image
 *    already uploaded through this proxy. It cannot be pointed at an expensive
 *    model or an arbitrary URL.
 *
 * The Replicate token itself is never exposed by any of these paths, which is
 * the property being bought here: a compromised app key is rotated with two
 * commands and costs you a capped amount of credit. A compromised Replicate
 * token is unlimited spend on your account.
 *
 * For a stronger boundary, mint short-lived tokens after Play Integrity /
 * App Attest attestation and check those here instead. See the README.
 */

const encoder = new TextEncoder();

/** SHA-256 of a string, so comparisons always run over 32 equal bytes. */
async function digest(value: string): Promise<ArrayBuffer> {
	return crypto.subtle.digest('SHA-256', encoder.encode(value));
}

/**
 * Constant-time app-key check.
 *
 * Both sides are hashed first: `timingSafeEqual` requires equal lengths, and
 * comparing raw keys would leak the expected length by throwing (or by
 * short-circuiting) on a mismatch. Hashing makes every comparison identical
 * work regardless of what was supplied.
 */
export async function appKeyMatches(provided: string, expected: string): Promise<boolean> {
	const [a, b] = await Promise.all([digest(provided), digest(expected)]);
	return crypto.subtle.timingSafeEqual(a, b);
}

/** An opaque per-install identifier, used for rate limiting and quota. */
const DEVICE_ID_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;

export interface Caller {
	/** The device id the client sent. */
	device: string;
}

/**
 * Authenticates a request, or throws the response the caller should get.
 *
 * Failures are deliberately identical (`401`, same body) whether the key is
 * missing, malformed or wrong — a probing client learns nothing about which.
 */
export async function authenticate(request: Request, appKey: string): Promise<Caller> {
	const provided = request.headers.get('x-app-key') ?? '';
	if (provided.length === 0 || !(await appKeyMatches(provided, appKey))) {
		throw new HttpError(401, 'Unauthorized.');
	}

	const device = request.headers.get('x-device-id') ?? '';
	if (!DEVICE_ID_PATTERN.test(device)) {
		// A well-formed id is required because it keys the rate limiter and the
		// quota: accepting anything would let a caller mint a fresh identity per
		// request and walk straight past both.
		throw new HttpError(400, 'A valid X-Device-Id header is required.');
	}

	return { device };
}
