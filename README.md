# ai_enhancer

Enhanzo — a Flutter photo enhancer. The enhance tools run on Replicate's
[`daanelson/real-esrgan-a100`](https://replicate.com/daanelson/real-esrgan-a100)
(Real-ESRGAN with optional GFPGAN face restoration).

## Running it

Credentials live in a gitignored `.env` at the repo root — create it with these
keys and fill in the values:

```
REPLICATE_PROXY_URL=
REPLICATE_APP_KEY=
REVENUECAT_API_KEY_ANDROID=
META_INTERSTITIAL_PLACEMENT_ID=
META_REWARDED_PLACEMENT_ID=
META_TESTING_DEVICE_HASH=   # optional, for Meta test ads
```

Then:

```sh
flutter run --dart-define-from-file=.env
```

`--dart-define-from-file` is Flutter's own flag — no package, and the key is
never bundled as an asset. It reads `KEY=VALUE` lines and turns each into a
compile-time define, which is why `ReplicateConfig` names the *variables*
(`String.fromEnvironment('REPLICATE_API_TOKEN')`, etc.) rather than holding
keys itself.

In VS Code the **Enhanzo** launch configuration passes the flag already; the
**Enhanzo (demo, no credentials)** one deliberately omits it.

### Mode 1 — direct token (development only)

```
REPLICATE_API_TOKEN=r8_…
```

**A token compiled into a mobile binary is extractable.** `.env` keeps it out
of source control, not out of the app bundle — anyone who unpacks the APK/IPA
gets it, and a leaked Replicate token is unlimited spend on your account with
no ceiling. Fine for your own device; never ship a build with this set.

### Mode 2 — Cloudflare proxy (production)

```
REPLICATE_PROXY_URL=https://replicate-proxy.<you>.workers.dev
REPLICATE_APP_KEY=…
```

The app holds no Replicate token at all. `cloudflare/replicate-proxy/` is a
Cloudflare Worker that holds the real token behind an encrypted secret, checks
an app key + rate limit + daily quota before forwarding anything, and only
runs one pinned model at a bounded scale. **Full setup walkthrough — Cloudflare
account through production deploy —** is
[cloudflare/replicate-proxy/README.md](cloudflare/replicate-proxy/README.md).

With neither mode set the app still runs its **simulated pipeline** on the
bundled demo photography, so the whole flow is demonstrable without an account.
Uploading a real photo in that build fails with a message naming the missing
config, rather than returning sample art as if it were your edit.

## Starting an edit

A tool opens the crop step directly; the **Upload a photo** button lives there,
under the canvas, alongside the frame chips. Until something is uploaded the
canvas shows the tool's sample imagery, labelled `SAMPLE`, and the button
becomes **Change photo** once a photo is in. Home carries no upload control of
its own.

## What runs on the model

| Tool | `scale` | `face_enhance` |
| --- | --- | --- |
| AI Enhance | 2 | true |
| HD Upscale | 4 | false |
| Unblur | 4 | true |
| Restore Photo | 4 | true |

The rest of the catalog (background, object and generation tools) is a different
class of model and is not wired to anything. Picking one with a real photo fails
with a message saying so rather than returning demo art as if it were your edit.

## The pipeline

`lib/data/` holds it, and `FlowController` in `lib/state/app_state.dart` drives
it:

1. `photo_library.dart` — pick from the library or camera, downsized on the way
   out. Driven by the crop step's upload button
   (`lib/screens/flow/photo_source_sheet.dart`).
2. `image_ops.dart` — centre-crop to the frame chosen on the crop step. What
   that canvas shows is exactly what is uploaded.
3. `replicate/replicate_client.dart` — upload to the Files API, create the
   prediction with `Prefer: wait`, poll until it settles, download the output.
   Sends a Replicate `Authorization` header in direct mode, or an
   `X-App-Key` + `X-Device-Id` pair in proxy mode (see `replicate_config.dart`,
   `device_id.dart`).
4. The result is saved under the app's documents directory, compared against the
   uploaded source on the result screen, and can be shared as a real file.

Backing out of the processing screen cancels the prediction server-side, so an
abandoned edit stops costing money.

## Platform notes

- iOS: photo-library and camera usage strings are in `ios/Runner/Info.plist`.
- Android: `INTERNET` is declared in the main manifest (release builds need it).
- macOS: the sandbox has `com.apple.security.network.client`.
- Web is not a target — the pipeline works in `dart:io` files.

## Tests

```sh
flutter test
```

`test/replicate_test.dart` pins the request contract (model version, input keys,
call order) and the failure and cancellation paths against a mock HTTP client,
so nothing there touches the network. `test/replicate_proxy_test.dart` proves
the client sends proxy headers (and no direct token) once a proxy is
configured — run it with
`--dart-define=REPLICATE_PROXY_URL=… --dart-define=REPLICATE_APP_KEY=…` to
exercise that branch for real.

The Worker has its own tests-by-construction: `cloudflare/replicate-proxy/README.md`
sections 8 (Local Testing) and 9 (Deploy) are curl sequences that double as the
acceptance check for that project.
