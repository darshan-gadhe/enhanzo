# Enhanzo — Store Listing (App Store + Play Store)

Production metadata for `com.techneoo.ai.photo.enhancer`, version `1.0.0` (build 1).

Everything below is written against what the app **actually does today**. Four
tools run on real inference (Replicate's Real-ESRGAN): **AI Enhance, HD
Upscale, Unblur, Restore Photo**. The rest of the catalog (background/object
removal, watermark removal, AI Expand, Inpainting) has UI but no model behind
it yet — nothing below advertises those, and they should stay unadvertised
until `RealEsrgan.supports()` actually covers them (see
`lib/data/replicate/real_esrgan.dart`). Overclaiming here isn't a copywriting
risk, it's a guideline-3.1.2 / false-advertising / 1-star-review risk, in that
order.

---

## Before you submit — real blockers, not nice-to-haves

Check these off before either store submission; each one *will* cause a
rejection or a broken listing, not just a suboptimal one.

- [ ] **Hosted privacy policy URL.** The policy text itself is done and shown
      in-app (Settings -> Privacy Policy), and publishable copies are generated
      at `store/privacy-policy.html` / `store/terms-of-use.html` by
      `dart run tool/build_legal.dart`. What is still missing is somewhere
      public to host them: Play Console's "Privacy policy" field requires a
      reachable URL, and an in-app copy does not satisfy it. The same URLs are
      what RevenueCat's paywall footer links need. No live URL, no submission.
- [x] **Real support contact.** `AppInfo.supportEmail` is
      `itechcoderdev@gmail.com`, and the same address is given in the Privacy
      Policy and Terms.
- [x] **App icon.** Real launcher icons are committed across all seven
      density buckets and verified present in the release bundle. See
      "App Icon" below for the spec; once you have the mark, say
      the word and I'll wire the generator so both platforms' full icon sets
      come from one source file.
- [ ] **Real screenshots.** Nothing below is a generated image — it's the
      *copy* to put on each screenshot. The screenshots themselves have to be
      captured from a real run of the app (device or simulator); I can't
      produce app-UI screenshots directly.
- [ ] **Subscription product IDs.** `Catalog.plans` (Weekly / Yearly) exists
      in the UI, but `EntitlementController.purchase()` still runs the
      simulated flow from prototyping — see the earlier billing conversation.
      The plans can't go live on either store until real product IDs exist in
      Play Console / App Store Connect and the purchase flow is wired to them.
- [ ] **Territory-correct pricing display.** The paywall currently hard-codes
      `₹399/wk` / `₹3,900/year` regardless of the store territory a user is
      in — that's a real bug for a global launch, not a metadata item. Once
      real product IDs exist, the displayed price should come from the store
      (`in_app_purchase`'s `ProductDetails.price`), not a hard-coded string.
- [ ] **Auto-renewable subscription disclosure (Apple Guideline 3.1.2).**
      Required *in the app binary itself*, near the purchase button, not just
      in the listing: subscription title, length, price (and per-unit price),
      plus functional links to the privacy policy and Terms of Use/EULA. The
      billed total must be the most visually prominent price on that screen —
      any trial or "per week" breakdown must be smaller/subordinate to it.
      `PremiumScreen` will need this text once billing is real.

---

## Quick reference

| Field | Value |
|---|---|
| App name | Enhanzo: AI Photo Enhancer |
| Short name (icon label) | Enhanzo |
| Android package | `com.techneoo.ai.photo.enhancer` |
| iOS bundle ID | `com.techneoo.ai.photo.enhancer` |
| Version | 1.0.0 (build 1) |
| Primary category | Photo & Video (Apple) / Photography (Google) |
| Price model | Free with auto-renewable subscription (Weekly, Yearly) |

---

## 1. App Store (Apple)

### App Name (30 char max)
```
Enhanzo: AI Photo Enhancer
```
26 characters.

### Subtitle (30 char max)
```
Unblur, Restore & Upscale
```
25 characters. Names the three real capabilities, not a vague tagline —
subtitle is indexed for search, so specificity here is doing ASO work, not
just branding.

### Promotional Text (170 char max, editable anytime without a new build)
```
Turn blurry, low-res or damaged photos into sharp, clear images in one tap. AI-powered enhancement, upscaling up to 8K, and face restoration for old photos.
```
156 characters. This is the field to update seasonally (e.g. around
Mother's Day / holidays, when "restore old photos" search volume spikes) —
it ships instantly, no review needed.

### Keywords field (100 bytes max)
```
image,hd,4k,8k,resolution,blur,sharpen,face,repair,old,damaged,background,remove,bg,upscaler,deblur
```
99 bytes. Deliberately contains no word already in Name/Subtitle (enhanzo, ai,
photo, enhancer, unblur, restore, upscale) — Apple indexes all three fields as
one 160-character pool, so repeating a word there wastes budget. See
`store/aso-keywords.md`-equivalent reasoning below for the full pool and an
alternate B-set.

### Description (4,000 char max — not indexed for search, written for
conversion)
```
Enhanzo turns blurry, low-resolution, or damaged photos into sharp, clear
images — right on your phone, no computer or editing skill required.

WHAT ENHANZO DOES

AI Enhance
A one-tap quality boost for any photo. Sharper detail, cleaner color, better
overall clarity.

HD Upscale
Increase a photo's resolution for printing or a bigger, clearer view — up to
8K export.

Unblur
Fix a photo that came out blurry from motion or missed focus. Recover detail
that looked lost.

Restore Photo
Repair an old, faded, or damaged family photo, with face restoration built in
for portraits.

HOW IT WORKS

1. Choose a photo from your library or take a new one.
2. Pick a tool and frame your crop.
3. Enhanzo processes it and shows you a before/after comparison you can drag
   through side by side.
4. Save it to your history or share the result.

BUILT FOR REAL PHOTOS

Enhanzo is built around one honest before/after comparison, everywhere in the
app — what you see is what the tool actually did to your photo, not a
simulated preview. Export sizes go up to 8K for printing or archiving.

PRIVACY

Your photo is sent only to the enhancement service needed to process it —
never sold, never used for advertising, and there's no account or login
required to use the app.

ENHANZO PRO

A subscription unlocks every AI tool, exports up to 8K, and removes ads and
watermarks. Weekly and yearly plans are available, both with pricing shown
before you subscribe.

Subscriptions renew automatically unless cancelled at least 24 hours before
the end of the current period. Manage or cancel anytime in your Apple ID
account settings. See our Terms of Use and Privacy Policy for full details.

Questions or feedback? Reach us anytime — we read every message.
```
This is written in natural sentences, not a keyword list — Apple's
description field isn't indexed for search ranking at all, so its only job is
converting a visitor who already found the listing into an install.

### What's New / Release Notes (v1.0.0 — initial launch)
```
Welcome to Enhanzo.

• AI Enhance, HD Upscale, Unblur, and Restore Photo — four AI tools for
  turning a blurry, low-res, or damaged photo into a sharp one.
• Export up to 8K.
• A real before/after comparison for every edit, not a simulated preview.
• Your finished edits collect in History so you can revisit or share them
  anytime.

Thanks for trying Enhanzo — we'd love your feedback.
```

### Category
- **Primary:** Photo & Video
- **Secondary:** Utilities

### Age Rating (iOS 26 five-tier system: 4+ / 9+ / 13+ / 16+ / 18+)
Enhanzo has no user-generated content shared with others, no chat/social
features, no web browser, no gambling, and processes only photos the user
themselves selects. Expected questionnaire answers:

| Question | Answer |
|---|---|
| Violence, sexual content, profanity, horror | None |
| Alcohol/tobacco/drug use or references | None |
| Gambling / contests | None |
| Unrestricted web access | No |
| User-generated content shared with other users | No (History and edits are private to the device; sharing is via the OS share sheet to *outside* the app, not a public feed inside it) |
| Age restrictions on user-generated content | Not applicable |

Expected result: **4+**. Confirm against the actual live questionnaire in App
Store Connect at submission time — Apple's exact wording changes periodically
and the console is the authority, not this document.

### Screenshots
**Required:** 6.9" iPhone, **1320 × 2868 px** (or 1290 × 2796 px), PNG/JPEG,
RGB, no alpha. Apple scales this down to populate every smaller device
automatically — you only need to supply the largest size.
**If the app supports iPad:** 13" iPad, **2064 × 2752 px**.

Screenshot content plan (5 screens, matching the app's real flow):

1. **Home / tool grid** — caption: *"Four AI tools. One tap."*
2. **Crop step with a real photo loaded** — caption: *"Frame it, then let AI take over."*
3. **Before/after slider on a result** — caption: *"Drag to see the difference — this is the actual result, not a preview."*
4. **Processing screen (live reveal)** — caption: *"Watch it enhance in real time."*
5. **History grid** — caption: *"Every edit, saved and ready to share."*

### App Preview video
Optional; not included here since no video asset exists. If you produce one
later, it needs to be captured from the real app (screen recording), 15–30
seconds, same device sizes as screenshots.

### App Icon
**1024 × 1024 px**, PNG, **no alpha channel**, **no pre-rounded corners** —
Apple applies the mask itself; a source image with corners already rounded
gets double-masked and looks wrong. Flat sRGB or Display P3, no transparency
anywhere in the file.

### Privacy — App Store "Privacy Nutrition Label" (App Store Connect → App
Privacy)
Declare based on what actually happens, not a template:

| Data type | Collected? | Notes |
|---|---|---|
| Photos or Videos | **Yes** | The photo the user selects is sent to the enhancement backend (Replicate, via the Cloudflare proxy in production) to be processed. Declare as "used to provide the app's core functionality." |
| Identifiers (device ID) | Likely **Yes**, "not linked to identity" | A random UUID generated on-device (not the OS advertising ID or hardware serial) is sent to the rate-limiting backend. It identifies an *installation*, not a person, and isn't tied to an account. |
| Contact Info, Location, Financial Info, Health, Browsing/Search History, Contacts | **No** | Nothing in the app reads or transmits any of these. |
| Usage Data / Analytics | **No** | No analytics SDK is present in the app (confirm this stays true if one is added later). |
| Advertising Data | **No** | No ad SDK is present. |

Precision matters here — App Store Connect's own privacy questionnaire is the
authority; treat this table as the factual input to it, not a substitute for
answering it yourself.

---

## 2. Google Play Store

### Title (30 char max)
```
Enhanzo - AI Photo Enhancer
```
27 characters.

### Short description (80 char max)
```
Restore old photos, unblur pictures & upscale images to HD with AI.
```
67 characters. This is the **second-most-important indexed field on Play**
after the title — every word here is doing ranking work, unlike Apple's
description field.

### Full description (4,000 char max, fully indexed — natural language, not a
keyword list)
```
Enhanzo is an AI photo enhancer that restores old, damaged, and blurry
photos in one tap. Fix a grainy old family photo, unblur a picture that's
out of focus, or upscale a low-resolution image to HD, 4K, or 8K — with face
restoration built in for portraits and old scans.

WHAT YOU CAN DO

• AI Enhance — a one-tap quality boost for any photo
• HD Upscale — increase photo resolution up to 8K
• Unblur — fix motion blur and out-of-focus shots
• Restore Photo — repair old, damaged, and faded family photos, with face
  restoration for portraits

WHO IT'S FOR

Whether you're digitizing old family photos, preparing an image to print
at a larger size, or just want to fix a pixelated picture before sharing it,
Enhanzo turns a low-quality photo into a sharp, clear one — right from your
phone.

HOW IT WORKS

Pick a photo, choose a tool, and Enhanzo shows you an honest before/after
comparison you can drag through — the exact result, not a simulated preview.
Save your edit to History or share it directly.

PRIVACY, PLAINLY

Your photo is sent only to the service that processes it. Enhanzo has no ad
tracking, no account required, and doesn't sell your data.

ENHANZO PRO

Unlock every AI tool, export up to 8K, and remove ads and watermarks with a
Weekly or Yearly subscription. Pricing is shown clearly before you subscribe,
and subscriptions can be managed or cancelled anytime from Google Play.

Have feedback or found an issue? We read every message — reach out anytime.
```

### Category
**Photography**

### Tags (up to 5 — Play Console suggests these based on category; confirm
exact available tag names in-console at submission time, since Play's tag
vocabulary isn't fully exposed outside it)
Candidates to look for in Play Console's suggested list: `Photo Editor`,
`AI`, `Photography Tools`, `Image Editor`, `Photo & Video`.

### Content rating (IARC questionnaire)
Same underlying facts as the App Store table above: no violence, no sexual
content, no user-generated content shared publicly, no gambling, no
unrestricted web access, no location collection. Expected result:
**Everyone / PEGI 3**. Answer the live IARC questionnaire in Play Console
directly — it's the only authoritative source for the final rating.

### Data safety section
Same factual basis as the Apple privacy table, mapped to Play's categories:

| Category | Declare | Purpose |
|---|---|---|
| Photos and videos | Collected, **not** shared with third parties for their own use | App functionality (the core enhancement feature) |
| Device or other IDs | See note below | Rate limiting / abuse prevention |
| Personal info, Location, Financial info, Health & fitness, Messages, Web browsing, App activity beyond the above | Not collected | — |

**On the device ID:** Google's April 2025 policy update requires disclosing
`Settings.Secure.ANDROID_ID` and similar OS-level identifiers under "Device or
other IDs." Enhanzo's identifier (`DeviceId` in
`lib/data/replicate/device_id.dart`) is a random UUID the app generates and
stores itself — not `ANDROID_ID`, not the advertising ID, not a hardware
serial. Whether Play's form requires it under that category anyway is a
judgment call for the in-console questionnaire (or counsel), not something
this document can resolve for you — but wherever you land, "collected for app
functionality, not linked to identity, not used for advertising" is the
accurate description of what actually happens.

Also required: **is data encrypted in transit?** Yes (HTTPS throughout, both
direct-to-Replicate and via the Cloudflare proxy). **Can users request data
deletion?** There's no server-side account to delete data from today — say so
plainly in the privacy policy rather than implying a deletion flow that
doesn't exist.

### Screenshots
**Phone:** minimum 2, up to 8. Aspect ratio between 16:9 and 9:16, resolution
between 320px and 3840px on the long edge. Recommended: **1080 × 1920 px**
(Full HD portrait) — displays well across virtually every Android phone.
**Tablet (optional):** 7" at 1200 × 1920 px, 10" at 1600 × 2560 px.
Format: JPEG or 24-bit PNG, **no alpha channel**, max 8MB per file.

Use the same 5-screen content plan as the App Store section above — one
consistent story across both stores.

### Feature Graphic (required, Play-only — no App Store equivalent)
**1024 × 500 px**, JPEG or 24-bit PNG, no transparency. This banner sits at
the top of the listing and in search/browse cards — it needs to work as a
strip, not a full scene. Recommended content: the Enhanzo wordmark
left-aligned, the before/after divider mark from the logo concept work as the
visual anchor, on the same monochrome background used everywhere else in the
brand. Avoid dense text — this is seen small, in a scrolling list, most often.

#### Feature Graphic — GPT image prompt

Written as prose, not comma-tags — GPT's image model follows a described
scene more reliably than a keyword list. Paste directly:

```
Design a wide banner graphic for a mobile app store listing, in a landscape
2:1 aspect ratio. The composition is a single clean horizontal strip, built
to be read correctly even when shown small in a scrolling list.

Left half of the banner: the app's wordmark "Enhanzo" set in a bold, rounded,
ultra-heavy geometric sans-serif typeface — confident and tightly tracked,
similar in weight and character to Outfit Black or Poppins ExtraBold. Directly
beneath it, a short tagline in a much lighter weight of the same typeface:
"AI Photo Enhancer."

Right half of the banner: a large circular or squircle mark, split down the
middle by one clean vertical divider line. The left portion inside the mark
is rendered as a soft grid of small square pixels (a degraded, low-quality
"before"). The right portion is a smooth, unbroken solid fill with a single
subtle rounded highlight (a sharp, enhanced "after"). Where the divider line
crosses the outer edge of the mark, it ends in one small filled circular
node, a quiet nod to a before/after comparison slider — not a literal UI
screenshot, not a rendered photograph, just the geometric idea of it.

Style: ultra-minimal, flat, geometric vector illustration. No gradients, no
drop shadows, no bevels, no glass or skeuomorphic effects, no glowing
particles, no sparkles, no camera or lens iconography, no rendered facial
features, no mascot or cartoon character, no 3D. Precise, confident linework,
generous negative space, the restraint of a modern SaaS or fintech brand
banner rather than a busy mobile-game graphic.

Color: strictly monochrome. Pure near-black mark and wordmark on a pure white
background, OR pure white on a near-black background — pick one, do not mix.
No blue/purple AI-app gradient, no neon, no rainbow.

Format: flat 2D graphic design asset, plain solid background edge to edge, no
drop shadow beneath the whole banner, no mockup device or browser frame
around it, no extra logos, no watermark, crisp clean edges, high resolution.
```

**Generation note:** GPT's image tool doesn't take an exact pixel size like
1024×500 — request the closest wide ratio it supports (ask for landscape,
roughly 2:1, or explicitly "ultra-wide") and it will render at one of its own
supported sizes. After generating, crop/resize precisely to **1024 × 500 px**
before uploading to Play Console — don't rely on the generator's output
dimensions matching exactly. Check the result at actual display size (it
appears quite small in search/browse cards) before finalizing; if the
wordmark reads as a blur at that size, regenerate with less text weight
crowding the left half rather than shrinking the type further.

### App Icon
**512 × 512 px** hi-res icon for the store listing (32-bit PNG, alpha
allowed). Separately, the app binary itself needs an **adaptive icon**: a
foreground layer (mark only, transparent background, kept inside the center
~66% safe zone of a 108dp/432px canvas) and a background layer (solid fill),
so the icon crops correctly to whatever shape a given Android launcher uses
(circle, squircle, rounded square). Both derive from the same source mark —
once you have it, `flutter_launcher_icons` generates all of this from one
file.

---

## 3. Shared: full ASO keyword pool

For reference across both stores — pull from this when refreshing metadata
later, or A/B testing the iOS keyword field:

**Head terms:** `ai photo enhancer` · `photo upscaler` · `image upscaler` ·
`ai image enhancer`

**Long-tail (lower competition, higher intent):** `unblur photo` · `fix
blurry photo` · `restore old photos` · `increase photo resolution` ·
`sharpen image` · `face restoration` · `deblur image` · `upscale to 4k` ·
`upscale to 8k`

**Memory-preservation niche (underserved, high-intent):** `digitize old
family photos` · `restore grandparents photos` · `preserve old photographs` ·
`scan and restore old photos`

**Output-driven intent:** `increase photo resolution for printing` ·
`enlarge photo without losing quality` · `photo dpi enhancer`

**Competitor-gap terms** (contested but not saturated among Remini, Clarify,
Sharpify, Revivio): `unblur face photo` · `fix grainy old photo` · `hd photo
converter free`

**Deliberately excluded — do not use:** any competitor product or model name
("Nano Banana," "GPT," any other app's brand name) — Enhanzo doesn't call
those APIs, and both stores treat naming a competitor's trademark you don't
have a genuine relationship with as grounds for rejection or removal, not a
style note. Also excluded: anything implying background removal, object
removal, watermark removal, or image generation — those tools exist in the
UI with no model behind them yet.

---

## 4. Copyright / legal line
```
© 2026 techneoo. All rights reserved.
```
Matches `PRODUCT_COPYRIGHT` in `macos/Runner/Configs/AppInfo.xcconfig` and the
Windows `LegalCopyright` resource string — keep this in sync if the entity
name changes.
