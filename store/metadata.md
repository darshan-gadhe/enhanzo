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

- **It described five tools while twelve shipped.** Object removal, people
  removal, watermark removal, the eraser, inpainting, canvas expansion and
  background replacement were all missing — seven working tools earning
  nothing, several of them high-volume queries in their own right.
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
Enhanzo: AI Photo Enhancer```

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

`80 char max — 71 used`

```
Unblur, restore & upscale photos, erase objects and remove backgrounds.```

Second-heaviest field, and shown above the fold. Four distinct high-volume
intents in one line: unblur, restore old, upscale HD, remove background.

---

## Full description

`4000 char max — 3569 used`

The previous version used 1,477 of 4,000 — 63% of the largest indexed field on
Play left empty. This one earns the space with real use cases and natural
keyword placement rather than repetition, which Play's spam policy penalises.

```
Enhanzo is an AI photo editor that repairs, upscales and cleans up your
pictures in one tap — on your phone, with no editing skill and no desktop
software.

Unblur a shot that came out soft. Restore an old family photo that has faded
or been scratched. Upscale a small, pixelated image so it holds up printed.
Brush over a person, an object or a watermark and have it erased and the space
behind it rebuilt. Cut a subject out into a transparent PNG. Every result comes
back as a real before/after you can drag through — the actual output, never a
simulated preview.

ENHANCE AND REPAIR

• AI Enhance — a one-tap quality boost for any picture. Sharper detail,
  cleaner colour, with face enhancement for portraits.
• HD Upscale — an AI image upscaler that raises photo resolution up to 4x, for
  printing, framing or enlarging.
• Unblur — a blurry photo fixer for motion blur and missed focus. It recovers
  detail rather than just sharpening edges.
• Restore Photo — old photo restoration for faded, grainy, scratched and
  damaged prints, with AI face restoration. Ideal for scanned family photos.

ERASE AND CLEAN UP

Brush over what you want gone, and the AI rebuilds what was behind it.

• Object Removal — erase an unwanted object from a photo.
• Remove People — clear a photobomber or a crowd out of your shot.
• Watermark Remove — clean a logo or stamp off a picture you own.
• Magic Eraser — brush away anything: wires, signs, blemishes, clutter.

BACKGROUNDS

• Remove BG — an automatic background remover that returns a transparent PNG,
  ready for a product listing, a sticker or a profile picture.
• Replace BG — swap the background for white, a green screen or a soft blur.

GENERATE

• Inpainting — paint over an area, describe what belongs there, and the AI
  fills it in. Results come back at 512px, this model's native size.
• AI Expand — extend the canvas beyond the edges of your photo and let the AI
  generate what continues the scene.

WHO ENHANZO IS FOR

• Anyone digitising old family photos, scans and albums
• Anyone with a blurry, grainy or pixelated picture worth saving
• Sellers who need clean product cut-outs and white backgrounds
• People clearing strangers and clutter out of their holiday photos
• Anyone preparing an image to print, frame or share

HOW IT WORKS

1. Pick a photo from your gallery, or take a new one.
2. Choose a tool and frame your crop — or keep the whole picture.
3. For the brush tools, paint over the part you want changed.
4. Enhanzo processes it and shows an honest before/after comparison.
5. Save it to History, or share it straight out of the app.

Nothing is cropped away unless you ask. Photos are resized proportionally, so
the whole composition — and everyone in it — reaches the AI intact.

PRIVACY, PLAINLY

No account and no sign-up. Your photo is sent only to the AI service that
processes it, and is never sold or used to train anything. Edits stay on your
device and are cleared automatically after 30 days. Full policy in Settings.

FREE AND PREMIUM

Enhanzo is free to try — every tool is available on the free tier, with three
enhancements included and occasional full-screen ads between edits.

Enhanzo Premium gives unlimited enhancements and removes ads. Weekly and
yearly plans are available and the price is shown before you subscribe.
Subscriptions renew automatically unless cancelled at least 24 hours before
the period ends, and can be managed or cancelled anytime in Google Play.

Questions, or a photo that did not come out right? We read every message —
get in touch from Settings.
```

---

## What's new / release notes

`500 char max — 464 used`

```
Eight new tools, all powered by real AI models:

• Object Removal, Remove People, Watermark Remove and Magic Eraser — brush
  over anything and it is erased, with the space behind it rebuilt.
• Remove BG and Replace BG — transparent cut-outs, or swap in white, green
  or a blur.
• Inpainting — paint an area and describe what belongs there.
• AI Expand — extend your photo past its own edges.

Plus faster, more reliable processing and clearer errors throughout.
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

## Accuracy rule

Every tool named above is in `ToolModels` with a pinned model version, and each
has been run end to end against live Replicate. If a tool is ever removed from
`Catalog.categories`, take it out of this copy in the same change: an
advertised feature that is not in the build is the failure this file keeps
having.

Inpainting's 512px output is stated in the description rather than left to be
discovered — it is a 512px model, so a larger photo comes back smaller.

---

## Copyright line

```
© 2026 techneoo. All rights reserved.
```
