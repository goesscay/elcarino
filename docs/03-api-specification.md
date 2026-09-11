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

| Method | Path | Notes |
|---|---|---|
| GET | `/me` | current user + profile summary |
| GET | `/me/devices` | list registered push devices |
| POST | `/me/devices` | register FCM token |
| DELETE | `/me/devices/{id}` | on logout/uninstall |

## Profiles — `/api/v1/profiles`

| Method | Path | Notes |
|---|---|---|
| GET | `/me` | own full profile |
| PUT | `/me` | update bio, goals, gender, birth_date etc. |
| POST | `/me/photos` | upload photo → object storage; queues moderation |
| DELETE | `/me/photos/{id}` | |
| PUT | `/me/photos/order` | reorder, body: ordered id array |
| GET | `/{userId}` | another user's public profile (subject to block/report state) |

## Interests — `/api/v1/interests`

| Method | Path | Notes |
|---|---|---|
| GET | `/` | full interest catalogue (public, cacheable) |
| PUT | `/me` | replace the current user's selected interests |

## Prompts — `/api/v1/prompts`

| Method | Path | Notes |
|---|---|---|
| GET | `/` | active prompt library, by category |
| GET | `/me` | current user's answered prompts, ordered |
| PUT | `/me` | upsert answers + `sort_order` |
| DELETE | `/me/{promptId}` | remove one answer |

## Preferences — `/api/v1/preferences`

| Method | Path | Notes |
|---|---|---|
| GET | `/me` | age/distance/gender/advanced filters |
| PUT | `/me` | update `user_preferences`; advanced filters (religion, politics) included |

## Discovery — `/api/v1/discovery`

| Method | Path | Notes |
|---|---|---|
| GET | `/feed` | paginated candidate profiles — applies preferences, radius, and excludes already-swiped/blocked users |
| GET | `/feed?refresh=1` | force a fresh batch (e.g. after boost activation) |

Response includes only the rounded distance (e.g. `"distance_km": 4`) — **never raw
coordinates** (spec §9).

## Swipes — `/api/v1/swipes`

| Method | Path | Notes |
|---|---|---|
| POST | `/` | body: `{ "target_id", "direction": "left|right|super" }`; returns `{ "matched": bool, "match_id": ... }` on mutual like |
| POST | `/rewind` | **[PROPOSED, TBD-11]** undo the last swipe — subscriber-gated |

## Matches — `/api/v1/matches`

| Method | Path | Notes |
|---|---|---|
| GET | `/` | list active matches, ordered by most recent activity |
| GET | `/{id}` | match detail |
| DELETE | `/{id}` | unmatch |
| GET | `/who-liked-me` | **[PROPOSED]** premium-gated list from `likes` |

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
