# ASO Strategy — Enhanzo

What actually moves rank on Google Play, ordered by leverage, with what this
project is and is not doing about each.

`aso-keywords.md` is research input. `metadata.md` is the copy. This file is
the part that decides whether either matters.

---

## The honest starting point

Play ranks on two things, roughly: **relevance** (does the listing match the
query) and **quality** (do people install, keep, and rate it well). A keyword
bank only touches the first, and only through three fields.

Before this pass the listing had a bigger problem than keyword coverage: it
described a different app.

| Problem | Cost |
|---|---|
| Background removal absent from listing and from 2,577 keywords | The app's newest tool, and one of the category's highest-volume queries, earned nothing |
| 63% of the full description unused (1,477 of 4,000) | The largest indexed field, more than half empty |
| "8K exports" promised | Untrue since inputs were capped to the model's GPU budget |
| "Remove watermarks" promised | The app has never applied one |
| "Unlock every AI tool" promised | Free users already get every tool |

The last three are worse than useless. They win installs from people looking
for something else, who uninstall — and retention is a ranking input, so a
false keyword costs rank twice.

---

## 1. Ratings and reviews — the biggest lever you are not pulling

Rating is among the heaviest quality signals, and review *volume* affects how
much a rating is trusted.

Today, Settings → "Rate Enhanzo" opens the Play listing in a browser. Most
people never come back, so it converts close to nothing.

**Google's In-App Review API** shows the rating sheet inside the app, with no
context switch. Same users, a fraction of the friction. Ask at a moment that
has just gone well — a finished enhancement the user chose to save — never
after an error, and never on first launch.

Rules that keep it from backfiring, and from being throttled by Play's quota:

- ask once per user, at most, unless they dismiss without rating
- only after at least two successful saves, so the asker has something to say
- never after a failed run, a no-fill, or a paywall dismissal
- never within the first session

## 2. Localisation — the biggest untapped reach

Play ranks **per locale**. A listing that exists only in English competes only
in English-language searches. Translating the title, short description and
full description is the cheapest install multiplier available, and it does not
require translating the app itself — a localised listing on an English app
still ranks and still converts.

Priority markets for a photo-restoration app, by category volume and by how
well "restore old family photos" travels:

1. Hindi, Indonesian, Portuguese (BR), Spanish (LatAm) — high volume, low
   competition, strong old-photo intent
2. Russian, Turkish, Vietnamese, Thai
3. German, French, Japanese, Korean

Translate the *keywords*, not the sentences. "Photo enhancer" has a natural
equivalent in each market that is rarely a literal translation.

## 3. Store listing experiments — free, and unused

Play Console → Grow → Store presence → Store listing experiments. A/B the
title, the icon, the feature graphic and the short description against live
traffic, with Play measuring install conversion for you.

Start with the title, because it is both the heaviest ranking field and the
highest-variance conversion element. Three candidates are in `metadata.md`.

Run one variable at a time, to statistical significance, and keep the winner.

## 4. Custom store listings

Play Console lets you serve a different listing by country, by install state,
or by acquisition channel. The obvious one here: a listing for users who
previously installed and churned, leading with what has changed since.

## 5. The first 170 characters

Play shows roughly this much of the full description before "Read more", and
weights the opening more heavily. `metadata.md` opens with the head term and
the four strongest verbs — unblur, restore, upscale, remove background —
before any brand language.

## 6. Screenshots and feature graphic

Play does not index text in images, so this is pure conversion, not relevance.
It still compounds: conversion rate feeds the quality signal that feeds rank.

- lead with a before/after, because that is the product
- caption every screenshot with the benefit, not the feature name
- first two screenshots carry most of the decision

## 7. Retention and technical quality

Android vitals — crash rate, ANR rate, cold start — are ranking inputs and can
suppress a listing outright when they exceed Play's bad-behaviour thresholds.
Worth watching after every release, not once.

## 8. Measure, then rewrite

Play Console → Grow → Store performance → **Search terms** shows the queries
that actually delivered your installs, with impressions and conversion.

That report beats every keyword list, including this project's. Use the bank
to seed the first version; use the report to write the second. Rewrite around
terms that already convert rather than terms that look high-volume.

---

## Sequence

1. Ship the corrected listing from `metadata.md` — accuracy first, since two
   claims in the old copy could draw a policy flag on their own.
2. Add the in-app review prompt.
3. Turn on a title experiment.
4. Localise the top four markets.
5. Wait for four weeks of search-term data, then rewrite the description
   around what converted.

Steps 1 and 2 are in this repo. Steps 3 to 5 are Play Console work that needs
the app published first.
