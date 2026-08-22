import { HttpError } from './http';

/**
 * Abuse and spend controls.
 *
 * Two layers, because they answer different questions:
 *
 * * **Rate limiting binding** — "is this device hammering us right now?" Cheap,
 *   in-memory, per Cloudflare location, 10s or 60s windows only.
 * * **KV daily quota** — "has this device already spent a day's worth of
 *   credit?" Survives across locations and hours, which the rate limiter
 *   cannot: its counters are per-location and its longest window is a minute.
 *
 * Neither is an accounting system. The rate limiting API is documented as
 * permissive and eventually consistent, and KV is eventually consistent too, so
 * a determined attacker can overshoot a little at the edges. They bound the
 * blast radius; they do not make it exact. Billing alerts on the Replicate
 * account remain the backstop.
 */

/** Checks a rate limiter, throwing 429 when the caller is over. */
export async function enforceRateLimit(limiter: RateLimit, key: string): Promise<void> {
	const { success } = await limiter.limit({ key });
	if (!success) {
		throw new HttpError(429, 'Too many requests. Please wait a moment and try again.');
	}
}

/** UTC day stamp, e.g. `2026-08-04`. */
function today(): string {
	return new Date().toISOString().slice(0, 10);
}

/**
 * How many predictions this device has started today.
 *
 * Read-then-write rather than an atomic counter: KV has no atomic increment,
 * and a Durable Object per device would cost more than the few predictions a
 * race could leak. If exactness ever matters, that is the upgrade.
 */
export async function checkDailyQuota(kv: KVNamespace, device: string, quota: number): Promise<{ used: number; key: string }> {
	const key = `quota:${today()}:${device}`;
	const raw = await kv.get(key);
	const used = raw === null ? 0 : Number.parseInt(raw, 10) || 0;
	if (used >= quota) {
		throw new HttpError(429, `Daily limit of ${quota} enhancements reached. Try again tomorrow.`);
	}
	return { used, key };
}

/**
 * Records one more prediction against the day's quota.
 *
 * Written with a two-day TTL so yesterday's keys expire themselves — nothing
 * accumulates in KV and there is no cleanup job to forget about.
 */
export async function recordUsage(kv: KVNamespace, key: string, used: number): Promise<void> {
	await kv.put(key, String(used + 1), { expirationTtl: 60 * 60 * 48 });
}
