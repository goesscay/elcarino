# API Specification — REST, `/api/v1`

Companion to [`02-database-schema.md`](02-database-schema.md). This is the contract the
Flutter app and the Laravel backend build against — treat changes to a shipped
endpoint's shape as breaking.

## Cross-cutting standards

Every route below is subject to all of the following unless explicitly marked `public`:

- **Authentication:** Laravel Sanctum bearer token.
- **Authorization:** policy check on the resource (e.g. a user can only edit their own
  profile; only a subscriber can message an unmatched user — see §Chat).
- **Validation:** Form Request classes; 422 with field-level errors on failure.
- **Resources:** responses shaped via API Resource classes, never raw Eloquent models.
- **Rate limiting:** per-route throttling, tightest on `auth/otp`, `swipes`, and
  `chat/messages` (abuse/scraping surface).
- **Error envelope, for business-rule failures a controller raises deliberately**
  (invalid credentials, expired OTP, invalid OAuth token, etc.) — every such
  response across every feature uses this shape:
  ```json
  { "error": { "code": "string_error_code", "message": "human readable" } }
  ```
  **422 request-validation failures** (a Form Request's rules didn't pass) use
  Laravel's standard shape instead — `{ "message": "...", "errors": { "field":
  ["msg"] } }` — rather than being force-fitted into the envelope above. This is
  a deliberate, documented exception, not drift: reshaping framework-level
  validation errors would mean re-implementing `assertJsonValidationErrors()`
  and every client-side validation-error helper for no real benefit. A client
  distinguishes the two by shape: an `error` key means a business-rule
  rejection; an `errors` key means fix the request body and resubmit.

## Auth — `/api/v1/auth`

| Method | Path | Notes |
|---|---|---|
| POST | `/register` | email or phone; creates `users` row |
| POST | `/login` | email/phone + password → Sanctum token |
| POST | `/otp/request` | rate-limited hard; sends OTP via SMS provider |
| POST | `/otp/verify` | marks `phone_verified_at` |
| POST | `/oauth/google` | exchanges Google id token for a session |
| POST | `/oauth/apple` | exchanges Apple id token for a session |
| POST | `/logout` | revokes current Sanctum token |
| POST | `/password/forgot` | sends reset link/OTP |
| POST | `/password/reset` | |
| DELETE | `/account` | soft-deletes `users` row; queues data-retention job |

## Users — `/api/v1/users`

`PUT /me/location` was added to this group in Phase 1 item 5 (Discovery feed) — not
in the original table below. It's what actually populates `user_locations`, which the
discovery feed reads; there was previously no endpoint for it anywhere in this doc.
Body: `{latitude, longitude}`. Never returns coordinates back (docs/06 §4/§5 — exact
coordinates are "Critical" data); rounds to 3 decimal places server-side
(defense-in-depth — the client is also expected to send coarse coordinates, docs/06
§4) and rate-limited to 1 stored update / 5 min / user (`throttle:location-update`,
same doc).

| Method | Path | Notes |
|---|---|---|
| GET | `/me` | current user + profile summary |
| PUT | `/me/location` | *(added — see above)* upserts `user_locations`; 422 shape validation on out-of-range lat/long |
| GET | `/me/devices` | list registered push devices |
| POST | `/me/devices` | register FCM token |
| DELETE | `/me/devices/{id}` | on logout/uninstall |

## Profiles — `/api/v1/profiles`

**Implemented (Phase 1 — Onboarding flow, backend slice).** `GET`/`PUT /me` return/accept
`display_name`, `birth_date`, `gender`, `bio`, `relationship_goal`; the response also
carries the derived `is_verified` and `completion_pct`, plus a nested `photos` array.
Photo uploads are re-encoded server-side and EXIF-stripped
(`docs/06-security-architecture.md` §6); each photo resource is
`{id, url, sort_order, moderation_status}` — `url` is a short-lived **signed** URL
(never the raw storage path), regenerated per request from
`config('media.signed_url_ttl_minutes')`.

| Method | Path | Notes |
|---|---|---|
| GET | `/me` | own full profile; 404 (`profile_not_found`) before it's been created |
| PUT | `/me` | update bio, goals, gender, birth_date etc. — upsert, not create-only |
| POST | `/me/photos` | upload photo → object storage; queues moderation. 422 if the profile doesn't exist yet, or the `media.max_photos_per_profile` cap (6) is hit |
| DELETE | `/me/photos/{id}` | owner-only (`ProfilePhotoPolicy`) |
| PUT | `/me/photos/order` | reorder, body: ordered id array; 422 (`invalid_photo_ids`) if the set isn't exactly the caller's own photos |
| GET | `/{userId}` | **not yet implemented** — its authorization depends on match/block state that doesn't exist until Discovery/Matching (Phase 1 items 5–7) land |

## Interests — `/api/v1/interests`

**Implemented (Phase 1 feature 3 — Profile module).** `GET /me` was added to this
group — not in the original table below — for the same reason prompts and
preferences each have one: the Edit-interests screen needs to know what's already
selected to pre-check it. `PUT /me` is a full replace (`sync()`, since this is a
plain many-to-many with no extra pivot columns, unlike prompts). No count is
specified anywhere in `/docs` for interests, so `media.max_interests_per_profile`
(15) is a provisional cap, not a tracked decision.

| Method | Path | Notes |
|---|---|---|
| GET | `/` | full interest catalogue (public, cacheable) |
| GET | `/me` | current user's selected interests *(added — see above)* |
| PUT | `/me` | replace the current user's selected interests |

## Prompts — `/api/v1/prompts`

**Implemented.** `PUT /me` is a full replace (deletes+recreates the caller's answers in
one call) capped at `media.max_prompts_per_profile` (3, per the Prompts screen spec) —
no server-side minimum; that's a soft client-side onboarding gate per
`docs/07-ui-ux-design.md` §3.1.

| Method | Path | Notes |
|---|---|---|
| GET | `/` | active prompt library, by category |
| GET | `/me` | current user's answered prompts, ordered |
| PUT | `/me` | upsert answers + `sort_order` (full replace) |
| DELETE | `/me/{promptId}` | remove one answer; 404 (`prompt_answer_not_found`) if there wasn't one |

## Preferences — `/api/v1/preferences`

**Implemented.** `religion_filter`/`politics_filter`/`relationship_goal_filter` are
free-form string arrays, not a fixed enum — decision #10 confirms the filters must
exist, not their option taxonomy, and no value list is defined anywhere in `/docs`.
Flag to the client if fixed lists are wanted.

| Method | Path | Notes |
|---|---|---|
| GET | `/me` | age/distance/gender/advanced filters; 404 (`preferences_not_found`) before they're set |
| PUT | `/me` | update `user_preferences`; advanced filters (religion, politics) included |

## Discovery — `/api/v1/discovery`

**Implemented (Phase 1 items 5 + 7).** Inclusion filters are the *viewer's own*
preferences (gender, age range, distance, relationship goal) — one-directional; mutual
matching stays out of scope (nothing here requires the target to want the viewer back,
only that the viewer's stated preferences match the target). Ranking layers item 7
(Matching engine v1) on top: candidates are ordered by `shared_interests_count`
(descending) first, then by `distance_km` (ascending), then by id. Per
`docs/01-technical-specification.md` §10, this is deliberately **not** a compatibility
score — "do not hardcode a scoring algorithm in Phase 1" — so `shared_interests_count`/
`shared_interests` are a plain, transparent count and name list, never blended into one
opaque number. 422s: `location_required` / `preferences_required` if the viewer hasn't
set either yet (`PUT /users/me/location`, `PUT /preferences/me`). Response shape:
`{"candidates": [{id, display_name, age, bio, relationship_goal, is_verified,
distance_km, shared_interests_count, shared_interests, photos, prompts}], "meta":
{page, per_page, has_more}}`. `refresh=1` is accepted but currently a no-op — there's
no feed cache yet for it to bust.

| Method | Path | Notes |
|---|---|---|
| GET | `/feed` | paginated candidate profiles — applies preferences, radius, and excludes already-swiped/blocked users |
| GET | `/feed?refresh=1` | force a fresh batch (e.g. after boost activation) — currently a no-op, see above |

Response includes only the rounded/bucketed distance (`distance_km`) — **never raw
coordinates** (spec §9). Per docs/06-security-architecture.md §4, `distance_km: 0` is
the sentinel for "less than 1 km away" (the client renders that copy); otherwise it's
rounded to the nearest km, or nearest 5 km beyond 30 km. Candidates are sorted by this
*bucketed* value, never the raw distance — docs/06 §4 explicitly forbids sorting by
exact distance, since that leaks precision an attacker could triangulate by repeatedly
moving their own location.

## Swipes — `/api/v1/swipes`

**Implemented (Phase 1 item 6).** `SwipePolicy::create` rejects self-swipes and either
direction of block (403); a repeat swipe on the same target is a 422
(`already_swiped`) — `swipes` has a unique `(actor_id, target_id)` per docs/02, so this
is permanent per pair, not just "until you unmatch." `super` is accepted (matches the
schema enum) and can trigger a match exactly like `right`, but none of Super Like's
proposed extras (limits, premium gating, a distinct match celebration) are built —
those are [TBD-11], pending open decision #11.

| Method | Path | Notes |
|---|---|---|
| POST | `/` | body: `{ "target_id", "direction": "left|right|super" }`; returns `{ "matched": bool, "match_id": ... }` on mutual like |
| POST | `/rewind` | **[PROPOSED, TBD-11]** undo the last swipe — subscriber-gated |

## Matches — `/api/v1/matches`

**Implemented.** `other_user` in each match's response is the same "public profile
projection" shape as the discovery feed's candidates, minus `distance_km` (matches
aren't distance-scoped) — see `MatchedUserResource`. Unmatch is soft (`unmatched_at`/
`unmatched_by`, per docs/02), so a match can't be unmatched twice (`UserMatchPolicy`
denies it — 403) and unmatched matches simply drop out of `GET /`'s list rather than
being deleted.

| Method | Path | Notes |
|---|---|---|
| GET | `/` | list active matches, ordered by most recent activity |
| GET | `/{id}` | match detail |
| DELETE | `/{id}` | unmatch |
| GET | `/who-liked-me` | **[PROPOSED]** premium-gated list from `likes` — not built; Phase 2 (subscriptions) doesn't exist yet for the gate to check against |

## Chat — `/api/v1/chat`

| Method | Path | Notes |
|---|---|---|
| GET | `/conversations` | inbox, ordered by `last_message_at` |
| GET | `/conversations/{id}/messages` | paginated history |
| POST | `/conversations/{id}/messages` | **server-side rule:** if the conversation's match is unmatched, reject with 403 unless `request.user->isSubscriber()` — this is the mandatory unmatched-messaging gate (spec §12), enforced here, not just in the app UI |
| PUT | `/conversations/{id}/read` | marks messages read |
| WS | `presence:conversation.{id}` | typing indicator + online/offline via Reverb channel |

## Calls — `/api/v1/calls` — **[PROPOSED]**, subscriber-only

| Method | Path | Notes |
|---|---|---|
| POST | `/token` | issues a WebRTC/Agora session token — **rejects non-subscribers server-side** (spec §13 gate) |
| POST | `/{id}/end` | logs call duration for analytics/support |

## Notifications — `/api/v1/notifications`

| Method | Path | Notes |
|---|---|---|
| GET | `/` | paginated, unread-first |
| PUT | `/{id}/read` | |
| PUT | `/read-all` | |

## Subscriptions — `/api/v1/subscriptions`

| Method | Path | Notes |
|---|---|---|
| GET | `/plans` | public — active `subscription_plans` |
| GET | `/me` | current subscription status/entitlements |
| POST | `/` | start a subscription (provider-specific receipt validation) |
| POST | `/cancel` | |

## Payments — `/api/v1/payments`

| Method | Path | Notes |
|---|---|---|
| GET | `/history` | current user's payment history |
| POST | `/webhook/{provider}` | **public**, signature-verified — gateway callback, not user-facing |

## Verification — `/api/v1/verification`

| Method | Path | Notes |
|---|---|---|
| POST | `/request` | submits selfie/ID per chosen method (open decisions #21–23) |
| GET | `/status` | current `verification_requests` state for the user |

## Safety — `/api/v1/safety`

| Method | Path | Notes |
|---|---|---|
| POST | `/block` | body: `{ "user_id" }` |
| DELETE | `/block/{userId}` | |
| POST | `/report` | body: `{ "user_id", "category", "description" }` |
| GET | `/report-categories` | public — enum list for the report form |

## Admin (Filament, not under `/api/v1`)

Admin CRUD/dashboards are served by Filament resources directly against the same
database — no separate admin REST surface to design/maintain. Only build a dedicated
`/api/v1/admin/*` endpoint if a native admin mobile experience is ever requested (not
currently in scope).
