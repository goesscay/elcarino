# Open Decisions Tracker

The 30 items the client needs to confirm before/during development (from the original
proposal). Per the planning conversation: development proceeds on the **working
assumption** in each row so nothing is blocked, but none of these are final. Update the
status column as answers land, and grep the codebase/docs for the `[TBD-#]` tag to find
every place a given decision is currently assumed rather than confirmed.

Status legend: 🔴 Open · 🟡 Partially answered · 🟢 Confirmed

## Product

| # | Decision | Working assumption | Status |
|---|---|---|---|
| 1 | Exact target niche / community | Not yet defined — building generic-but-safety-focused UX that a niche layer can sit on top of | 🔴 |
| 2 | Brand name | **Elcarino** / `com.mgs.elcarino`, brand red `#DC2626` — logo in [`/branding`](../branding) | 🟢 |
| 3 | Countries for initial launch | Malaysia first, then Maldives and India | 🟢 |
| 4 | Age restrictions | 18+ minimum (hard gate at signup via `birth_date`), no upper bound. Confirmed as the working policy — revisit only if a launch market's law requires stricter | 🟢 |
| 5 | Relationship categories | Free-text `relationship_goal` for now; convert to enum once list is confirmed | 🔴 |

## Matching

| # | Decision | Working assumption | Status |
|---|---|---|---|
| 6 | Gender options | **Man / Woman / Non-binary** — `profiles.gender` enum; "interested in" is a multi-select of the same three (`user_preferences.interested_in_genders`) | 🟢 |
| 7 | Age range | User-configurable min/max in `user_preferences`, no hard platform limits beyond #4 | 🟡 |
| 8 | Distance range | User-configurable `max_distance_km`, platform cap TBD (assume 200 km max) | 🟡 |
| 9 | Matching criteria | Rule-based v1 (preferences + interest overlap); AI score deferred to Phase 4 | 🟡 |
| 10 | Advanced filters | Religion + politics confirmed by client as required; schema supports both | 🟢 |

## Premium

| # | Decision | Working assumption | Status |
|---|---|---|---|
| 11 | Number of subscription plans | Assume 1 free + 1 premium tier for MVP; schema supports N via `subscription_plans` | 🔴 |
| 12 | Pricing | Not set — no figures in any client-facing material yet | 🔴 |
| 13 | Premium benefits | Per proposal: unlimited likes, advanced filters, boost, unmatched messaging, voice/video calling | 🟡 |
| 14 | Boost system | Visibility-window mechanic built (Phase 2 item 3): an active boost ranks a candidate first in others' discovery feeds for `config('discovery.boost_duration_minutes')` (30, an implementation default, not confirmed with the client). "Frequency" is the real, plan-configurable `entitlements.boosts_per_month` — no specific number is confirmed as a business figure | 🔴 |
| 15 | Unmatched-messaging rules | Subscriber-only, enforced server-side (spec §12) | 🟢 |

## Communication

| # | Decision | Working assumption | Status |
|---|---|---|---|
| 16 | Voice notes | Scheduled Phase 3, assume in-scope pending confirmation | 🔴 |
| 17 | GIFs | Scheduled Phase 3, assume in-scope pending confirmation. Built (Phase 3 item 2): search-provider choice was itself unspecified — Giphy is this feature's engineering working default (industry standard for this exact use case), behind a provider-agnostic `GifProvider` interface, same pattern as #27's Stripe default. Not verified against any real Giphy response — the public beta key it falls back to when unconfigured turned out to be dead (confirmed live, 403 "BANNED" on every request), so this needs a real `GIPHY_API_KEY` and a fresh live check before relying on it, more so than #27's Stripe/#16's audio pipeline were | 🔴 |
| 18 | Photo sharing (in chat) | Scheduled Phase 3, assume in-scope pending confirmation. Built (Phase 3 item 3): reuses `ImageProcessor`/the mandatory EXIF-strip re-encode unchanged from profile photos (docs/06 §6) — no new business decision here, no separate size/dimension limits either (`media.max_photo_size_kb`/`max_photo_dimension` apply to both) | 🔴 |
| 19 | Voice calls | Scheduled Phase 3, provider TBD (WebRTC vs Agora) | 🔴 |
| 20 | Video calls | Scheduled Phase 3, same provider decision as #19 | 🔴 |

## Verification

| # | Decision | Working assumption | Status |
|---|---|---|---|
| 21 | AI verification | Assumed primary method (selfie-match pipeline) | 🔴 |
| 22 | Manual verification | Assumed fallback/appeal path for AI rejections | 🔴 |
| 23 | ID verification | Not assumed in scope unless required for a specific launch market's compliance | 🔴 |

## AI

| # | Decision | Working assumption | Status |
|---|---|---|---|
| 24 | AI compatibility score | Deferred to Phase 4; formula not started | 🔴 |
| 25 | AI icebreakers | Deferred to Phase 4; assume in-scope pending confirmation | 🔴 |
| 26 | AI profile assistance (e.g. bio suggestions) | Not currently scheduled in any phase — flag if wanted | 🔴 |

## Business

| # | Decision | Working assumption | Status |
|---|---|---|---|
| 27 | Payment gateway | Not selected by the client. Engineering working default as of Phase 2 item 1: Stripe (real, not yet verified against a live account) behind a provider-agnostic `PaymentGateway` interface; native store billing (App Store/Play Store) built as a separate, always-available path via real-but-unconfigured receipt verifiers. Still affects `subscriptions.provider`'s final real-world usage | 🔴 |
| 28 | App Store / Google Play subscription strategy | Assume native store billing (Apple/Google IAP) unless a gateway is chosen for #27 | 🔴 |
| 29 | Admin users | Assume MGS + client both have admin accounts at launch; roles/permissions TBD | 🔴 |
| 30 | Launch date | Not set — timeline in `04-development-phases.md` is duration-based, not date-based | 🔴 |

## Already answered (moved out of "open" once resolved)

| Decision | Answer |
|---|---|
| Target market / launch sequencing | Malaysia → Maldives → India |
| Vendor/company name for client-facing material | MGS |
| #2 Brand name | Elcarino / `com.mgs.elcarino`, brand red `#DC2626` |
| #4 Age restrictions | 18+ minimum, no upper bound |
| #6 Gender options | Man / Woman / Non-binary |
| Flutter state management (engineering, not a client decision) | Riverpod |
| Local dev database (engineering) | SQLite locally; PostgreSQL in staging/prod |
| Backend framework version (engineering) | Laravel 13 — latest stable at scaffold time (2026-09); spec originally said 12 |
| Flutter routing (engineering) | `go_router` |
