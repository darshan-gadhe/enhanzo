# Cloudflare + Replicate Proxy Setup Guide

Run every command below from this directory (`cloudflare/replicate-proxy/`).

## 1. Why use a Cloudflare Proxy?

If you store the **Replicate API Token** directly inside your Flutter app:

* Anyone can extract the APK/IPA and obtain your API token.
* A leaked token allows unlimited usage of your Replicate account, which can result in unlimited billing.

Instead, use the following architecture:

```text
Flutter App
      │
      ▼
Cloudflare Worker
      │ (Stores the real Replicate API Token securely)
      ▼
Replicate API
```

The Flutter app only stores an **APP_KEY**.

The actual **REPLICATE_API_TOKEN** is stored securely as a Cloudflare Secret and is never exposed to the mobile application.

The APP_KEY is still extractable from the app bundle — no client-side secret in
a distributed app can be otherwise. What changes is the blast radius: a leaked
Replicate token is unlimited spend forever until you notice; a leaked APP_KEY
is bounded by everything in section 3 below, and rotated with one command
(section 11).

---

# 2. What does the Cloudflare Worker do?

Whenever the Flutter app sends a request:

```text
Flutter App
     │
     │ X-App-Key
     │ X-Device-Id
     ▼

Cloudflare Worker

✔ Verify APP_KEY
✔ Verify Device ID
✔ Apply Rate Limits
✔ Check Daily Quota
✔ Validate Model Version
✔ Validate Scale
✔ Validate Uploaded Image

     │

Replicate API
(Bearer REPLICATE_API_TOKEN)

     │

Prediction Result

     ▼

Flutter App
```

The Worker validates every request before forwarding it to Replicate.

If any validation fails, the request is rejected immediately and never reaches Replicate.

---

# 3. Security Features

The Cloudflare Worker provides the following protections:

## APP_KEY Verification

* Only requests containing the correct APP_KEY are accepted (`src/auth.ts`,
  compared in constant time so a wrong guess can't be timed against a right
  one).

---

## Rate Limiting

* 5 AI predictions per minute per device
* 60 normal API requests per minute per device

This prevents spam and abuse (`src/limits.ts`).

---

## Daily Quota

* Maximum 40 image enhancements per device per day (`src/limits.ts`, stored in
  the `QUOTA` KV namespace).

---

## Model Validation

Only allow a specific pinned Replicate model version.

Reject requests targeting any other model (`src/validate.ts`).

---

## Scale Validation

Allow only:

```text
Scale <= 4
```

Reject larger upscale values.

---

## Image Validation

Only allow images uploaded through this proxy (i.e. a
`https://api.replicate.com/v1/files/...` URL this Worker itself returned).

Reject arbitrary external image URLs — otherwise a caller could use your
account to fetch any URL of their choosing.

---

## Response Filtering

Do not expose the full Replicate response.

Return only:

```text
id
status
output
error
```

This prevents unnecessary internal account information (URLs, logs, metrics)
from being exposed.

---

## No Browser Access

Requests carrying an `Origin` header are rejected outright, and no CORS
headers are ever sent. This is an API for the mobile app, not a web page — a
copy-pasted APP_KEY used from a browser tab doesn't work.

---

# 4. Cloudflare Account Setup

* Create a Cloudflare account at [dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up)
  and verify your email. Workers has a free tier (100,000 requests/day) —
  no credit card needed to deploy one.
* Install Node.js 18+.
* Install dependencies and authenticate Wrangler with Cloudflare:

```bash
npm install
npx wrangler login
```

`npx` runs the Wrangler version pinned in this folder's `package.json` — don't
install Wrangler globally, or you'll drift from what's tested here.
`wrangler login` opens a browser to authorize the CLI against your account.

---

# 5. Create a KV Namespace

The KV namespace will store the daily quota information.

Run:

```bash
npx wrangler kv namespace create QUOTA
```

Copy the generated Namespace ID into:

```text
wrangler.jsonc
```

under the KV namespace configuration (replacing
`PLACEHOLDER_REPLACE_WITH_YOUR_KV_ID`).

---

# 6. Configure Rate Limiting Namespaces

`wrangler.jsonc` also declares two rate-limit namespaces (`PREDICTION_LIMITER`,
`GENERAL_LIMITER`), each needing a `namespace_id`. Unlike KV, these aren't
created with a command — Cloudflare provisions one the first time you deploy
with a given id.

**Pick your own arbitrary positive integers**, unique within your account
(the defaults `1001`/`1002` are fine to leave as-is for a single Worker). If
you deploy more than one Worker with rate limiting on this account, give each
Worker's namespaces their own numbers.

---

# 7. Create Secrets

Create two secrets.

## Secret 1

```text
REPLICATE_API_TOKEN
```

Store your actual Replicate API token (from
[replicate.com/account/api-tokens](https://replicate.com/account/api-tokens)):

```bash
npx wrangler secret put REPLICATE_API_TOKEN
```

---

## Secret 2

```text
APP_KEY
```

Generate a secure random key:

```bash
openssl rand -base64 32
```

Store it:

```bash
npx wrangler secret put APP_KEY
```

This APP_KEY will also be added to the Flutter application.

**Do not reuse the APP_KEY across environments.** A staging key leaking
should never let someone spend against production quota.

---

# 8. Local Testing

Copy:

```bash
cp .dev.vars.example .dev.vars
```

Edit `.dev.vars`:

```text
REPLICATE_API_TOKEN=your_token

APP_KEY=your_random_key
```

Run:

```bash
npx wrangler dev
```

Test that the Worker is functioning correctly:

```bash
curl http://localhost:8787/health
# {"status":"ok"}

curl -X POST http://localhost:8787/v1/predictions \
  -H "X-App-Key: your_random_key" \
  -H "X-Device-Id: 00000000-0000-0000-0000-000000000000" \
  -H "Content-Type: application/json" \
  -d '{"version":"daanelson/real-esrgan-a100:f94d7ed4a1f7e1ffed0d51e4089e4911609d5eeee5e874ef323d2c7562624bed","input":{"image":"https://api.replicate.com/v1/files/x","scale":4,"face_enhance":true}}'
# {"detail":"The image must be a file uploaded through this API."}  -- correct: nothing was uploaded yet
```

**Rate limiting isn't fully enforced under plain `wrangler dev`** — a burst
that should return 429 may pass through locally. It works correctly once
deployed; don't take a clean local burst test as proof the limiter works.

---

# 9. Deploy

Deploy the Worker:

```bash
npx wrangler deploy
```

Example deployed URL:

```text
https://replicate-proxy.your-subdomain.workers.dev
```

This becomes your proxy endpoint (`REPLICATE_PROXY_URL`).

Smoke-test the deployed Worker with the same curl commands as section 8,
against this URL instead of `localhost:8787`. Confirm `/health` returns ok, a
missing APP_KEY returns 401, and a bad model version/scale/image URL returns
400 naming the problem — then run a real upload → predict → poll sequence
(section 10) to confirm it actually enhances a photo.

---

# 10. Flutter Configuration

Update your Flutter `.env` file:

```env
REPLICATE_API_TOKEN=

REPLICATE_PROXY_URL=https://replicate-proxy.your-subdomain.workers.dev

REPLICATE_APP_KEY=your_app_key
```

Leave `REPLICATE_API_TOKEN` empty.

The app should never communicate directly with Replicate.

All requests must go through the Cloudflare Worker.

Relaunch after editing — defines are compile-time, so hot reload won't pick
this up:

```bash
flutter run --dart-define-from-file=.env
```

---

# 11. Request Flow

```text
User
 │
 ▼
Select Image
 │
 ▼
Flutter App
 │
 ▼
Cloudflare Worker
 │
 ├── Verify APP_KEY
 ├── Verify Device ID
 ├── Rate Limit
 ├── Daily Quota Check
 ├── Validate Model
 ├── Validate Scale
 ├── Validate Uploaded Image
 │
 ▼
Replicate API
 │
 ▼
AI Enhancement
 │
 ▼
Cloudflare Worker
 │
 ▼
Flutter App
 │
 ▼
Enhanced Image
```

---

# 12. Secret Rotation

If the APP_KEY is compromised:

Generate a new APP_KEY:

```bash
npx wrangler secret put APP_KEY
```

Update the Flutter application's `.env`.

Rebuild and release the application.

Older app versions will receive HTTP 401 Unauthorized responses until updated.

---

# 13. View Logs

Monitor Worker activity:

```bash
npx wrangler tail
```

This provides real-time logs including:

* Request path
* HTTP method
* Response status
* Processing time
* Errors
* Device ID (truncated to 8 characters — the Replicate token is never logged)

For historical metrics, use the **Workers → replicate-proxy → Observability**
tab in the Cloudflare dashboard.

---

# 14. Update Limits

Modify the following values inside `wrangler.jsonc`:

* Rate Limits (`ratelimits[].simple.limit` / `.period` — `period` must be `10`
  or `60` seconds, a hard constraint of the binding)
* Daily Prediction Quota (`vars.DAILY_PREDICTION_QUOTA`)
* Maximum Upload Size (`vars.MAX_UPLOAD_BYTES`)
* Maximum Upscale Scale (`vars.MAX_SCALE`)
* Allowed Model Version (`vars.ALLOWED_MODEL_VERSION` — keep this in sync with
  `RealEsrgan.version` in the Flutter app's `lib/data/replicate/real_esrgan.dart`;
  a mismatch fails closed with a clear 400, never open)

After making changes, redeploy:

```bash
npx wrangler deploy
```

---

# 15. Billing Alerts

Every control above bounds the *cost* of abuse; none of them make it free. Set
a spend notification on the Replicate account itself —
[replicate.com/account/billing](https://replicate.com/account/billing) — so an
attack that gets past everything else still reaches you before the invoice
does. Do this before shipping; it's the actual backstop behind all of the
above.

---

# Goal

The objective is to build a secure Cloudflare Worker that:

* Never exposes the Replicate API token.
* Stores all secrets securely in Cloudflare Secrets.
* Uses APP_KEY authentication.
* Applies rate limiting and daily quotas.
* Validates model version, scale, and uploaded images.
* Returns only sanitized responses.
* Acts as the only gateway between the Flutter application and the Replicate API.
