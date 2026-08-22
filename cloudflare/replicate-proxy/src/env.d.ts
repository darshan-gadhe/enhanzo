// `wrangler types` generates bindings from wrangler.jsonc, but secrets are
// deliberately absent from that file (`wrangler secret put`, `.dev.vars`) —
// there is nothing there for it to read. This fills in the two it can't see.
// Re-run `npx wrangler types` after editing wrangler.jsonc; this file is
// untouched by that command and does not need regenerating with it.
interface Env {
	/** Set with `wrangler secret put REPLICATE_API_TOKEN`. */
	REPLICATE_API_TOKEN: string;
	/** Set with `wrangler secret put APP_KEY`. The shared secret the app sends
	 * as `X-App-Key`. */
	APP_KEY: string;
}
