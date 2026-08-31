# Enhanzo — Play Store Metadata

Copy fields, ready to paste into Play Console. Screenshot and icon specs, the
release checklist and the privacy-table reasoning live in `store/LISTING.md`;
keyword research lives in `store/aso-keywords.md`; what actually moves ranking
is in `store/aso-strategy.md`.

**Android only.** The App Store section that used to sit here has been removed
along with the rest of the iOS build — there is no Apple listing to fill in.

## What changed, and why it mattered

The previous copy described an app that no longer exists, in three ways that
each cost ranking rather than earning it:

- **It never mentioned background removal.** Remove BG ships now, and
  "background remover" is one of the highest-volume queries in the category.
  It appeared nowhere in the listing and nowhere in the 2,577-term keyword
  bank.
- **It promised 8K exports.** Inputs are capped to the model's GPU budget, so
  a typical photo now tops out around 6K. Every "8K" was removed rather than
  left to be discovered by a reviewer or a refund request.
- **It promised watermark removal.** The app has never applied a watermark to
  anyone, so there was none to remove, and "unlock every AI tool" was wrong
  too: free users get every tool — the limit is on how many runs, not which
  tools.

Keywords that describe features you do not have are worse than no keywords.
They win installs from people looking for something else, who then uninstall —
and retention is a ranking input.

---

## Title

`30 char max — 26 used`

```
Enhanzo: AI Photo Enhancer
```

The single most heavily weighted field. Brand first, then the head term
"AI Photo Enhancer" exactly as people type it.

**Variants worth running as a Play Console store listing experiment** — see
`aso-strategy.md`, this is free and you are not using it:

```
Enhanzo: AI Photo Enhancer          (26)  — control, head term
Enhanzo: Unblur & Enhance Photo     (29)  — leads with the strongest verb
Enhanzo: Photo Enhancer & BG        (28)  — buys the background-remover query
```

---

## Short description

`80 char max — 72 used`

```
Unblur photos, restore old pictures, upscale to HD & remove backgrounds.
```

Second-heaviest field, and shown above the fold. Four distinct high-volume
intents in one line: unblur, restore old, upscale HD, remove background.

---

## Full description

`4000 char max — 3349 used`

The previous version used 1,477 of 4,000 — 63% of the largest indexed field on
Play left empty. This one earns the space with real use cases and natural
keyword placement rather than repetition, which Play's spam policy penalises.

```
Enhanzo is an AI photo enhancer that makes blurry, low-resolution, old and
damaged pictures look sharp again — in one tap, on your phone, with no editing
skill and no desktop software.

Unblur a photo that came out soft. Restore an old family picture that has
faded or been scratched. Upscale a small, pixelated image so it holds up
printed or on a big screen. Cut a subject out of its background into a clean
transparent PNG. Every result comes back as a real before/after you can drag
through — the actual output, never a simulated preview.

WHAT YOU CAN DO

• AI Enhance — a one-tap quality boost for any picture. Sharper detail,
  cleaner colour, better overall photo quality, with face enhancement built in
  for portraits.

• HD Upscale — an AI image upscaler that increases photo resolution up to 4x.
  Turn a small or low-resolution photo into a high-resolution one for printing,
  framing or posting.

• Unblur — fix motion blur and out-of-focus shots. A blurry photo fixer that
  recovers detail that looked lost, rather than just sharpening edges.

• Restore Photo — old photo restoration for faded, grainy, scratched and
  damaged prints, with AI face restoration for portraits. Ideal for scanning
  and reviving old family photographs.

• Remove BG — an automatic background remover. It cuts out the subject and
  returns a transparent PNG, ready to drop onto a new background, a product
  listing, a sticker or a profile picture.

WHO ENHANZO IS FOR

• Anyone digitising old family photos, scans and albums
• Anyone with a blurry, grainy or pixelated picture worth saving
• Sellers and small businesses who need clean product cut-outs
• People preparing a photo to print, frame or enlarge
• Anyone who wants a picture to look better before sharing it

HOW IT WORKS

1. Pick a photo from your gallery, or take a new one.
2. Choose a tool and frame your crop — or keep the whole picture as it is.
3. Enhanzo processes it and shows you an honest before/after comparison.
4. Save it to your History, or share it straight out of the app.

Nothing is cropped away unless you ask for it. Photos are resized
proportionally so the whole composition — and everyone in it — reaches the AI
intact.

BUILT AROUND AN HONEST RESULT

Enhanzo shows the same before/after comparison everywhere in the app, on your
own photo. What you see is what the tool actually did — not a stock demo, not
a filtered preview. Your finished edits collect in History so you can revisit,
re-share or delete them later.

PRIVACY, PLAINLY

No account and no sign-up. Your photo is sent only to the AI service that
processes it, and is never sold or used to train anything. Edits stay on your
device and are cleared automatically after 30 days. Full policy in the app
under Settings.

FREE AND PREMIUM

Enhanzo is free to try — every tool is available on the free tier, with three
enhancements included and occasional full-screen ads between edits.

Enhanzo Premium gives you unlimited enhancements and removes ads. Weekly and
yearly plans are available, and the price is shown before you subscribe.
Subscriptions renew automatically unless cancelled at least 24 hours before
the period ends, and can be managed or cancelled anytime in Google Play.

Questions, a photo that did not come out right, or a feature you want? We read
every message — get in touch from Settings.
```

---

## What's new / release notes

`500 char max — 376 used`

```
• Remove BG — cut any subject out into a transparent PNG.
• Big reliability work on the enhancer: large photos are now resized safely
  before processing, so oversized pictures no longer fail.
• Clearer errors instead of technical messages when something goes wrong.
• Faster, more stable enhancement across every tool.

Thanks for using Enhanzo — tell us what to build next.
```

---

## Category and tags

**Category:** Photography

**Tags** (up to 5, from Play Console's fixed list):
`Photo Editor` · `AI` · `Photography Tools` · `Image Editor` · `Photo & Video`

---

## Subscription disclosure

Play requires the subscription terms to be legible before purchase. They are
stated in the full description above and rendered by RevenueCat's hosted
paywall from your Play offer — the app hardcodes no price and no trial.

**If your Play offer includes the 3-day free trial**, add this line to the
FREE AND PREMIUM section. Only add it if the offer is actually live, and check
it with the offering diagnostic (`OfferingDiagnostics`, debug builds) rather
than assuming:

```
New subscribers start with a 3-day free trial. Cancel any time before it ends
and you will not be charged.
```

---

## Copyright line

```
© 2026 techneoo. All rights reserved.
```
