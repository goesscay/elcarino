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

`/me/devices` (list/register/remove push devices) moved to its own "Devices" section
below (Phase 1 item 9) once it actually had implementation notes to carry.

## Profiles — `/api/v1/profiles`

**Implemented (Phase 1 — Onboarding flow, backend slice).** `GET`/`PUT /me` return/accept
`display_name`, `birth_date`, `gender`, `bio`, `relationship_goal`, and (Phase 2 item 2)
`religion`/`politics` — free-form, free for anyone to set (only *filtering* other people
by them is premium-gated, see Preferences below); owner-only, never exposed on any
resource another user can fetch. The response also carries the derived `is_verified`
and `completion_pct`, plus a nested `photos` array.
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

`religion_filter`/`politics_filter` are premium-gated (Phase 2 item 2, docs/06 §3.4):
attempting to *set or change* either to a non-empty value that differs from what's
already stored, without the `advanced_filters` entitlement, is rejected — `403 {
"error": { "code": "upgrade_required" } }` — but resubmitting the exact value already
on the row (e.g. a lapsed subscriber saving an unrelated field via this same
full-replace endpoint) is allowed through unchanged. The entitlement is re-checked
independently at read time (`DiscoveryFeedService`) regardless of what's stored, so
stale data from a lapsed subscription is never actually applied either way.

| Method | Path | Notes |
|---|---|---|
| GET | `/me` | age/distance/gender/advanced filters; 404 (`preferences_not_found`) before they're set |
| PUT | `/me` | update `user_preferences`; advanced filters (religion, politics) included, premium-gated per above |

## Discovery — `/api/v1/discovery`

**Implemented (Phase 1 items 5 + 7; Phase 2 items 2 and 3 add religion/politics and
boost).** Inclusion
filters are the *viewer's own* preferences (gender, age range, distance, relationship
goal, and — subscribers only — religion/politics) — one-directional; mutual matching
stays out of scope (nothing here requires the target to want the viewer back, only that
the viewer's stated preferences match the target). A candidate who hasn't stated their
own religion/politics is excluded by that filter rather than treated as a wildcard
match. Neither field is ever returned in the candidate response shape below — see
Profiles above on why. Ranking layers item 7
(Matching engine v1) on top: candidates are ordered by an active boost first
(item 3's "visibility window" — `POST /discovery/boost` below), then by
`shared_interests_count` (descending), then by `distance_km` (ascending), then by id. Per
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
| GET | `/boost` | *(added — Phase 2 item 3)* `{ "active", "ends_at", "used_this_month", "limit" }` — `limit` is `false` for a non-subscriber (never `0` as a stand-in for "no access") |
| POST | `/boost` | *(added)* activate a boost using one of the plan's monthly `boosts_per_month` allotment. `201 { "starts_at", "ends_at" }` on success. `403 upgrade_required` (not a subscriber, or the plan grants none), `409 boost_already_active`, or `403 boost_limit_reached` |

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

**Implemented (Phase 1 item 8), text only** — voice notes/GIFs/photo sharing stay
[TBD-16/17/18], unconfirmed. A `Conversation` is created automatically alongside every
`UserMatch` (`SwipeService`, item 6) — the inbox lists a fresh match with no messages
yet, per docs/07 §3.3, rather than only showing up once someone sends a first message.
`ConversationResource` includes `match_id` (so the client can call
`DELETE /matches/{id}` to unmatch straight from the inbox, no second round-trip to
`GET /matches`), `last_message_preview` (the latest message's `body`, `null` for a
fresh match with no messages yet — docs/07 §3.3's inbox row preview text),
`unread_count`, and `requires_subscription_to_message`
so the client can show the "subscribe to message" banner (docs/07's
Unmatched-conversation banner) without a wasted 403 round-trip. **Phase 2 item 4:**
this flag is the *viewer's* access, not just whether the conversation itself lacks an
active match — `requiresSubscriptionToMessage() && ! $viewer->isSubscriber()`. Before
item 1 gave `isSubscriber()` a real implementation this distinction was unreachable
(nobody could ever be a subscriber), so a subscriber viewing an unmatched conversation
would have seen the banner and a hidden composer despite `POST .../messages` actually
succeeding for them. Real-time delivery is
`ShouldBroadcastNow` (not queued) — `QUEUE_CONNECTION` is `database` locally with no
worker guaranteed running, and a message that silently never arrives because nobody
ran `queue:work` would be a bad failure mode; broadcasting synchronously costs one
extra HTTP round-trip to Reverb per message, the right trade here.

| Method | Path | Notes |
|---|---|---|
| GET | `/conversations` | inbox, ordered by `last_message_at` (a match with no messages yet sorts last, not dropped) |
| GET | `/conversations/{id}/messages` | paginated history, newest first |
| POST | `/conversations/{id}/messages` | **server-side rule:** if the conversation's match is unmatched (or there is none), reject with 403 `error.code = "subscription_required"` unless `request.user->isSubscriber()` — the mandatory unmatched-messaging gate (spec §12), enforced here, not just in the app UI. Rate-limited 30/min/conversation + 300/hour/user (docs/06 §7). Body: `body` (string, required unless `voice_note` or `gif_id` present) **or** `voice_note` (multipart file upload, audio, ≤ `media.max_voice_note_size_kb`) + `duration_seconds` (int, client-reported, required with `voice_note`) — Phase 3 item 1 (open decision #16) — **or** `gif_id` (string, from a prior `GET /gifs/search` result — never a raw URL, see below) — Phase 3 item 2 (open decision #17). Only one of `voice_note`/`gif_id` may be present at once. A voice-note message gets `type: "voice_note"`, `body: null`, and a populated `attachment` object in the response/resource (`url` — signed, short TTL per `media.chat_media_signed_url_ttl_minutes`; `mime_type`; `duration_seconds`). A gif message gets `type: "gif"` and `body` set to the *server-resolved* gif URL (`attachment` stays null — a gif is already public third-party-hosted content, nothing to store privately); an unknown/expired `gif_id` is rejected with 422 `error.code = "gif_not_found"` |
| PUT | `/conversations/{id}/read` | marks the *other* participant's unread messages read; broadcasts a read-receipt event so an open conversation screen updates live |
| WS | `presence-conversation.{id}` | typing indicator + online/offline via Reverb channel — a presence channel's own member list *is* the online/offline signal, and typing indicators are peer-to-peer client (`whisper`) events over the same channel; neither needs a REST endpoint. `routes/channels.php`'s authorizer reuses `ConversationPolicy::view`, so the socket subscription is gated by the exact same participant-and-not-blocked rule as the REST endpoints. Auth for the socket handshake goes through `POST /api/broadcasting/auth` (registered outside the `/api/v1` prefix — see `bootstrap/app.php`), Sanctum-bearer-token-guarded like every other endpoint. Server → client events: `message.new` (`{ "message": MessageResource }`, now including `attachment` when present), `messages.read` (`{ "read_by_user_id", "read_at" }`). Client → client (`whisper`) event: `client-typing` |

`message_attachments` (docs/02): voice notes (Phase 3 item 1, open decision #16) is its
only reader/writer — `MessageAttachment` model, `MessageAttachmentResource`. Gifs (#17)
deliberately don't use it — see the `POST` row above. Photo sharing (#18) still unbuilt;
revisit this table once that's confirmed.

## GIFs — `GET /gifs/search`

Phase 3 item 2 (open decision #17). Not nested under `chat/` — the client picks a gif
before knowing which conversation it'll end up sent to. Query: `q` (required string),
`page` (optional int, 1-indexed). Response: `{ "gifs": [GifResultResource], "meta": {
"has_more": bool } }`, where a `GifResultResource` is `{ id, preview_url, url, width,
height }`. Rate-limited 60/min/user. Proxies `GifProvider::search()` server-side rather
than the mobile app calling Giphy directly, so the API key never ships in the client and
the provider can be swapped without a mobile release. `id` from a result here is what
`POST /chat/conversations/{id}/messages`'s `gif_id` field takes — the client never sends
a gif's `url` directly, only the `id`; the server re-resolves it via `GifProvider::find()`
at send time.

## Media — `GET /media/message-attachments/{attachment}` — **outside `/api/v1`**

Signed (`media.chat_media_signed_url_ttl_minutes`), not Sanctum-guarded — same model as
the built-in `storage.local` route profile photos use, and outside `/api` for the same
reason (`bootstrap/app.php`'s `broadcasting/auth` comment): a native media player
fetching this URL carries no bearer token, only the signature. Only used on the `local`
disk (dev); a cloud disk (`s3`, staging/prod) keeps using `Storage::temporaryUrl()`
directly, unchanged. Exists instead of reusing `storage.local` because that route
doesn't support `Range` requests and re-sniffs `Content-Type` via `finfo`, which reports
an AAC-in-MP4 voice note as `video/mp4` — both broke playback on Android's native
`MediaPlayer`, confirmed live. See `MessageAttachmentStreamController`'s doc comment.

## Calls — `/api/v1/calls` — **[PROPOSED]**, subscriber-only

| Method | Path | Notes |
|---|---|---|
| POST | `/token` | issues a WebRTC/Agora session token — **rejects non-subscribers server-side** (spec §13 gate) |
| POST | `/{id}/end` | logs call duration for analytics/support |

## Notifications — `/api/v1/notifications`

**Implemented (Phase 1 item 9), delivery via Firebase Cloud Messaging (spec §18,
confirmed).** Every notification is first written to the `notifications` table
(docs/02) — even for a recipient with no registered device — then best-effort pushed
to each of the recipient's `user_devices`; a push failure never blocks or rolls back
the swipe/match/message that triggered it, it just leaves `sent_via_push` false.
`type` is one of `new_match`/`new_message`/`like` this feature — `subscription`/
`verification`/`report_status`/`system` are schema-reserved for features that don't
exist yet. **`like`'s `payload` deliberately carries no identity of the liker** — "who
liked me" is a separate, premium-gated browsing feature ([PROPOSED],
`GET /matches/who-liked-me` above) that reads the `likes` table directly; putting an
id here would let a free user see it for free through the notification feed, the same
"no derivative signal leaks precision" principle docs/06 §4 applies to location.

| Method | Path | Notes |
|---|---|---|
| GET | `/` | paginated, unread-first (`read_at IS NULL` first, newest-first within each group), `{ notifications: [{id, type, payload, read_at, created_at}], meta }` |
| PUT | `/{id}/read` | 403 if not the owner |
| PUT | `/read-all` | marks every one of the caller's unread notifications read |

`payload` (and the matching FCM `data` field, all values stringified there) by `type`:
`new_match` → `{match_id, conversation_id, other_user_id}`; `new_message` →
`{conversation_id, message_id}`; `like` → `{}` (see above). The mobile client's
tap-to-open routing (`NotificationTapGate`) switches on `type` — `new_match`/
`new_message` open `conversation_id`'s conversation, `like` opens the inbox
(no "who liked me" screen exists yet), everything else opens nothing (no screen
built for it yet either).

## Devices — `/api/v1/users/me/devices`

**Implemented (Phase 1 item 9).** `fcm_token` is unique across the whole table, not
scoped to the caller — the same installation can log out and a different account can
log back in on it and get handed the same token, so `POST` upserts by token
(reassigning `user_id` + refreshing `platform`/`app_version`/`last_seen_at`) rather
than failing as a duplicate or leaving a stale row nobody prunes.

| Method | Path | Notes |
|---|---|---|
| GET | `/` | the caller's own devices only — `fcm_token` itself is never echoed back |
| POST | `/` | body: `{ "fcm_token", "platform": "ios\|android", "app_version"? }`; upserts by `fcm_token` |
| DELETE | `/{id}` | on logout/uninstall; 403 if not the owner |

## Subscriptions — `/api/v1/subscriptions`

Phase 2 item 1 (docs/04). Open decision #27 (payment gateway) is
unresolved; Stripe is this feature's chosen working default
(`App\Services\Payments\StripePaymentGateway`, real but not yet verified
against a live account) — native store billing (`app_store`/`play_store`)
is a separate, always-available path via real-but-unconfigured
`ReceiptVerifier`s, same status as `TwilioSmsSender`/`FcmPushSender`.

| Method | Path | Notes |
|---|---|---|
| GET | `/plans` | "public" per the original table below, but kept behind auth like every other route in this app for now — same reasoning as `GET /prompts`'s library endpoint. Active `subscription_plans` only |
| GET | `/me` | `{ "subscription": SubscriptionResource\|null, "entitlements": {...} }` |
| POST | `/` | body: `{ "plan_id", "provider": "stripe"\|"app_store"\|"play_store", "receipt"? }` (`receipt` required for the two native providers; `"other"` is a valid `subscriptions.provider` enum value for schema completeness only — never accepted here). Response shape depends on provider: `provider: "stripe"` returns **either** `201 { "subscription": SubscriptionResource }` (the log-driven local-dev gateway, which activates synchronously) **or** `202 { "checkout_url": "..." }` (a real Stripe account — the subscription doesn't exist yet, `POST /webhooks/stripe` creates it once payment is confirmed). `provider: "app_store"\|"play_store"` always returns `201` synchronously once the receipt verifies |
| POST | `/cancel` | ends access immediately (`ends_at` -> now) — does **not** keep access until the current paid period ends, a real-billing-UX nicety this MVP doesn't implement (flagged, not silently the friendlier behaviour by accident) |

## Payments — `/api/v1/payments`

| Method | Path | Notes |
|---|---|---|
| GET | `/history` | current user's payment history |

## Webhooks — `/api/webhooks/*` (not under `/api/v1`, no Sanctum auth)

Same reasoning as `/api/broadcasting/auth` (`bootstrap/app.php`): the caller
isn't a mobile client and can't hold a bearer token, so each webhook's own
request signature is the entire authentication.

| Method | Path | Notes |
|---|---|---|
| POST | `/stripe` | `Stripe-Signature` header HMAC-verified against `STRIPE_WEBHOOK_SECRET` (`App\Services\Payments\StripeWebhookSignatureVerifier`) — `503` if unconfigured, `400` if the signature doesn't verify. Handles `checkout.session.completed` (activates the subscription), `customer.subscription.deleted` (cancels it), `invoice.payment_failed` (marks it `past_due`). **Not handled:** `invoice.payment_succeeded` extending `ends_at` on renewal — every subscription this feature creates gets exactly one billing period and then lapses even if Stripe keeps charging successfully. Flagged as the natural next fast-follow, not silently dropped |
| POST | `/webhook/{provider}` | **public**, signature-verified — gateway callback, not user-facing |

## Verification — `/api/v1/verification`

| Method | Path | Notes |
|---|---|---|
| POST | `/request` | submits selfie/ID per chosen method (open decisions #21–23) |
| GET | `/status` | current `verification_requests` state for the user |

## Safety — `/api/v1/safety`

**Implemented (Phase 1 item 10).** Blocking and reporting both reject self-targeting
with a 403 (`BlockPolicy`/`ReportPolicy`, same "can't act on yourself" shape as
`SwipePolicy`). Both endpoints below are also idempotent — blocking someone already
blocked, or unblocking someone not blocked, succeeds without erroring (`blocks`' own
`unique(blocker_id, blocked_id)` would otherwise throw on a repeat). **Blocking also
unmatches** (docs/07 §3.7's "Block confirm" dialog copy): the matching `UserMatch`, if
one is currently active between the two users, gets soft-unmatched in the same call —
enforced server-side, not left to the mobile UI, same discipline as every other
server-side rule in this app (docs/06 §3.4).

| Method | Path | Notes |
|---|---|---|
| GET | `/blocks` | *(added — see below)* the caller's own blocked users, `{ blocked_users: [{id, display_name, photo}] }` — null-safe for a target with no profile, since you can block/report any user id, not just a match |
| POST | `/block` | body: `{ "user_id" }` |
| DELETE | `/block/{userId}` | |
| POST | `/report` | body: `{ "user_id", "category", "description"?, "also_block"? }` — `also_block` *(added)*, docs/07 §3.7 "Report — detail": "option to also block". Rate-limited 20/day/user (docs/06 §7) |
| GET | `/report-categories` | public — enum list for the report form. Kept behind auth like every other route in this group for now, same reasoning as `GET /prompts`'s library endpoint |

`GET /safety/blocks` wasn't in this doc's original table — docs/07 §3.7's "Blocked
users (Settings child): List with unblock" needs a way to list them, added here in the
same commit that builds the screen it feeds.

## Admin (Filament, not under `/api/v1`)

Admin CRUD/dashboards are served by Filament resources directly against the same
database — no separate admin REST surface to design/maintain. Only build a dedicated
`/api/v1/admin/*` endpoint if a native admin mobile experience is ever requested (not
currently in scope).

**Built (Phase 1 item 11):** panel at `/admin`, session auth + mandatory TOTP
(docs/06 §3.3) — `Users` (search/view/suspend/reinstate/ban/delete) and `Reports`
(reports queue: mark actioned/dismiss, plus a combined "suspend reported user"
action) resources, and a dashboard with total/active/new-user, match, message, and
pending-report counts.

**Built (Phase 2 item 5):** `SubscriptionPlans` (full CRUD — the only admin-facing
place `subscription_plans.price_cents`/`entitlements` are ever set; open decision #12
still isn't answered by this, it's just no longer only seedable) — the entitlements
form is four fixed fields (`unlimited_likes`/`advanced_filters`/`unmatched_messaging`
booleans, `boosts_per_month` integer), not a generic key-value editor, since those are
the only keys anything in this app actually reads
(`App\Filament\Resources\SubscriptionPlans\Concerns\TransformsEntitlements`'s own doc
comment). No delete action — a plan with existing subscriptions can't be deleted
(`plan_id` has no cascade); `is_active` is the real "retire this plan" mechanism.
`Subscriptions` (list + a "Cancel" action, audit-logged — reuses the same
`SubscriptionService::cancel()` the mobile self-service path uses, but the audit
write happens at the admin-action call site, not inside that shared service, so a
user cancelling their own subscription never gets logged as an "admin action").
`Payments` (list only, no actions at all — no refund API wired). All three are
admin-only (`SubscriptionPlanPolicy`/`SubscriptionPolicy`/`PaymentPolicy`) — docs/06
§3.3: "Moderators: ... cannot touch subscription/payment data, cannot change plans."
Dashboard gained "Premium users" (distinct users with a currently-active subscription)
and "Revenue" (sum of every succeeded payment's `amount_cents` — correct only because
every plan so far uses USD; a genuinely multi-currency deployment would need
per-currency totals, flagged in `DashboardStats`' own doc comment).
