# Development Phases

Planning-level timeline (not a fixed commitment — see the proposal's Timeline &
Effort slide). Total: **20–28 weeks** end to end. Each phase has a checklist and a
**gate**: work does not start on the next phase until the current phase's gate passes.
This mirrors the discipline in [`CLAUDE.md`](../CLAUDE.md) — one feature at a time,
spec → implement → test → review → fix → commit.

---

## Phase 0 — Architecture & Design (~3–5 weeks)

**Goal:** everything needed to start writing feature code without re-deciding
fundamentals mid-build.

- [x] Technical specification (`01-technical-specification.md`)
- [x] Database schema (`02-database-schema.md`)
- [x] API specification (`03-api-specification.md`)
- [x] Security architecture review (`06-security-architecture.md`) — auth, authz,
      geolocation privacy, PII handling, the server-side enforcement points from spec
      §12/§13, rate limiting, audit, compliance flags
- [x] UI/UX design — **wireframe + IA layer** (`07-ui-ux-design.md`): full screen
      inventory, navigation map, per-screen specs, placeholder design system, state
      checklist. **High-fidelity visual design + clickable prototype still outstanding**
      — needs brand direction (decision #2) and ideally a visual designer.
- [x] Resolve enough of [`05-open-decisions.md`](05-open-decisions.md) to unblock
      Phase 1: gender options (#6 → man/woman/non-binary), age policy (#4 → 18+),
      state management (Riverpod), local DB (SQLite local / Postgres staging+prod).
      **#2 app name/branding is now confirmed:** **Elcarino** / `com.mgs.elcarino`,
      brand red `#DC2626` — logo in [`/branding`](../branding); full hi-fi visual
      design (imagery, illustration, clickable prototype) is still outstanding.
      **Still open (do not block Phase 1):** SMS/OTP provider (Phase 1 builds a
      provider-agnostic sender, default impl Twilio).
- [x] Repo, CI skeleton, environment config — `.gitattributes`,
      `.github/workflows/{backend,mobile}.yml`, `backend/.env.example` (all integration
      keys documented), `mobile/config/{dev,staging,prod}.json` + `AppConfig`,
      `docs/08-environment-setup.md`.
- [x] Laravel scaffolded in `/backend` (Laravel 13, SQLite local dev) — boots,
      migrates, `php artisan test` + Pint green. Flutter scaffolded in `/mobile`
      (Flutter 3.47.2, Riverpod, go_router, feature-first folders, themed placeholder
      home) — `flutter analyze` + `flutter test` green, **and `flutter build apk
      --debug` produces a valid `com.mgs.elcarino` APK** (JDK 17 + Android SDK 36
      installed, `flutter doctor` Android toolchain OK). Feature migrations/models land
      in Phase 1, one feature at a time.

**Gate — MET** (except hi-fi visual design):
- Design: wireframe + IA layer done (`07-ui-ux-design.md`); high-fidelity visual design
  + prototype still outstanding (needs brand direction #2 / a designer) — this is the
  one open gate item, and it does not block starting Phase 1 engineering.
- Backend: boots locally, `php artisan migrate` succeeds (Laravel default migrations —
  `02-database-schema.md` tables land per-feature in Phase 1), tests + lint green.
- Mobile: compiles to a debug APK; placeholder home renders under `flutter test`.
  Running on a device/emulator needs a connected Android phone or an AVD install
  (see `08-environment-setup.md`) — not required for the gate.

---

## Phase 1 — MVP (~6–8 weeks)

**Goal:** a real, testable dating app — no premium, no AI, no calls yet.

Build order (each item: spec confirmed → implement → automated tests → self-review →
fix → commit, before moving to the next):

1. [x] Authentication (email, phone+OTP, Google, Apple; logout, forgot password) —
       `users`/`otp_codes` migrations, Sanctum bearer tokens, rate limiting per
       security doc §7, provider-agnostic OTP sender (log locally, Twilio ready),
       Google/Apple ID-token verification. 24 backend tests, Pint clean, audit
       clean. **Deferred to a fast-follow, not silently dropped:** access+refresh
       token rotation (single expiring access token for now, security doc §2.1),
       account deletion, session/device management (`/users/me/devices`).
2. [x] Onboarding flow (account → profile basics → photos → prompts → preferences).
       **Backend:** `profiles`/`profile_photos`/`profile_prompts`/
       `user_profile_prompts`/`user_preferences` migrations; profile basics, photo
       upload with server-side EXIF-strip + signed URLs, prompts, preferences
       endpoints; 53 backend tests, Pint + audit clean. **Mobile:** all 12 screens
       in docs/07-ui-ux-design.md §3.1 (Splash, Welcome, Auth method, Email/Phone
       entry, OTP, Profile basics, Photos, Prompts, Preferences, Location
       permission, Notification permission, Onboarding complete), a typed
       `ApiClient` with bearer-token injection + the two documented error shapes
       mapped to `ApiException`/`ValidationException`, secure token storage, and
       an `OnboardingGate` that resolves a resumed session's next step from the
       API itself rather than a client-side flag. `flutter analyze` clean,
       9 mobile tests passing, `flutter build apk --debug` succeeds with the new
       plugins (image_picker, permission_handler, flutter_secure_storage) wired
       in. Deliberately deferred, not dropped: location capture (no endpoint
       exists yet — belongs with Discovery, item 5) and push-device registration
       (belongs with item 9) — those two onboarding screens request OS permission
       only, no backend call. Interests selection is out of scope too — it's an
       "Edit profile" (item 3) concern per the screen inventory, not an onboarding
       step. Google/Apple sign-in buttons exist but show "coming soon" — real
       OAuth needs GOOGLE_CLIENT_ID/APPLE_CLIENT_ID and native SDK setup that
       isn't configured. Photo reorder is left/right buttons, not drag-and-drop;
       the OTP input is one 6-digit field, not 6 separate boxes — both
       functionally equivalent simplifications of the wireframe, real
       drag/box-styling is a hi-fi-design-pass concern (docs/07 §4.5, still the
       one open Phase 0 gate item). Widget/unit tests cover the logic-heavy
       pieces (API error translation, the onboarding gate, app-boot routing);
       no per-screen form/widget tests were added given the size of this
       feature — flag if that coverage gap matters enough to close.
3. [x] Profile module (view/edit, photo upload + reorder + moderation queue).
       **Backend:** `interests`/`user_interests` migrations, GET `/`, GET/PUT
       `/me`; 61 backend tests. Photo upload/reorder reused unchanged from
       Onboarding (item 2), not rebuilt. **Mobile:** My profile (preview,
       completion meter, verification chip), Edit profile (menu ->
       Photos/Prompts/Basics & bio/Interests — the last three combined bio +
       basics + relationship-goal into one editor, a disclosed IA
       simplification), Edit preferences as a peer screen per docs/07 §3.5's
       table. Photos/Prompts/Preferences reuse the exact onboarding screens
       via an `onDone`/`continueLabel` param added for this — same widget,
       different exit behaviour, no duplicated grid/form code. 11 mobile
       tests passing (was 9), flutter analyze clean, `flutter build apk
       --debug` verified. **Moderation queue intentionally not built:**
       docs/03's Admin section is explicit that admin/moderation is a
       Filament resource, not a REST endpoint, and Filament isn't scaffolded
       until item 11 — a bespoke moderation endpoint now would contradict
       that. "Reorder answered prompts" (docs/07 §3.5 "Edit prompts") is item
       4's job, not this one — full-replace `PUT /prompts/me` already
       supports it mechanically (resubmit in the new order); the drag UI for
       it is scoped to item 4 below, not duplicated here. Settings (gear icon
       on My profile) shows "coming soon" — its children are scattered across
       features that don't exist yet (push notifications/item 9,
       safety/item 10).
4. [x] Profile prompts (library + answer + reorder). Library + answer already
       built in Onboarding (item 2). Added: `EditPromptsScreen`
       (`/profile/edit/prompts`) — a dedicated screen for docs/07 §3.5's "Edit
       prompts" (reorder/swap/edit an already-answered set), separate from
       onboarding's "pick 3 from scratch" picker since the doc describes them
       differently. Drag-to-reorder uses `ReorderableListView` and persists
       via the same full-replace `PUT /prompts/me` (resubmit in the new
       order sets `sort_order`) — no new backend endpoint. Swap/add uses the
       library picker + `PUT /prompts/me`; edit-in-place and remove use the
       existing update/`DELETE /prompts/me/{id}` calls, the latter finally
       called from mobile for the first time. 13 mobile tests passing (was
       11), flutter analyze clean, `flutter build apk --debug` verified.
5. [x] Discovery feed (filters, radius, exclude swiped/blocked).
       `PUT /users/me/location` (new endpoint, added to docs/03 in this commit) +
       `GET /discovery/feed`. Filters are the *viewer's own* preferences
       (gender/age/distance/relationship-goal) — one-directional; mutual
       matching + interest-overlap scoring stay item 7's job. `swipes` and
       `blocks` tables added now, schema-only — their write endpoints are
       items 6 and 10, but the feed needs to exclude against them today, and
       adding the tables later would mean a mid-flight schema change instead
       of an empty table now. Distance: PHP-side Haversine over a
       SQL-prefiltered, scan-capped candidate set (config/discovery.php),
       *not* a SQL geo query — docs/02's own indexing note says geohash
       bucketing is "the Phase-1 proximity approach... revisit only if it
       becomes a bottleneck"; this is even simpler than that, deferring
       geohash-based filtering too until the plain-Haversine approach
       actually struggles. The geohash column is still computed and stored
       (Geohash service, verified against the standard Wikipedia worked
       example) so that optimization is a query change later, not a
       backfill. Sorting is by *bucketed* distance only, per docs/06 §4's
       explicit anti-triangulation rule (never sort by the raw float).
       Candidates require ≥1 photo (any moderation status) — gating on
       *approved* photos would make the feed permanently empty pre-Filament
       (item 11), since nothing can ever be approved yet; flagged here as a
       must-fix before real users, not silently shipped. Location updates
       rate-limited to 1/5min (docs/06 §4) via a real `Limit::perMinutes`
       throttle, not just a comment. 92 backend tests (was 61), Pint +
       audit clean. **Mobile:** the onboarding Location-permission screen now
       actually captures a position (`geolocator`) and calls
       `PUT /users/me/location`, truncated to 3dp client-side too — it still
       degrades gracefully on any failure (permission denied, no GPS,
       network) rather than blocking onboarding, per docs/06 §4. New
       DiscoverFeedScreen (`/discover`) is a plain paginated browse list, not
       the swipe-gesture "Card stack" docs/07 §3.2 describes — the swipe
       action itself (POST /swipes, like/pass/match) is item 6, and building
       drag-gesture UI with nowhere for the gesture to persist to would mean
       reworking it once item 6 lands; replace this with the real card stack
       then. Handles both documented 422s (`location_required`,
       `preferences_required`) with inline guidance back to the relevant
       screen instead of a raw error. 15 mobile tests passing (was 13),
       flutter analyze clean, `flutter build apk --debug` verified with
       `geolocator` linked in.
6. [x] Swipe → like/pass → match. **Backend:** `POST /swipes` +
       `GET/DELETE /matches`, `GET /matches/{id}` (all added to docs/03 in
       this commit). `likes`/`matches` tables added (the former written on
       every right/super swipe, matching docs/02's stated purpose, though
       nothing reads it yet — "who liked me" stays [PROPOSED]/Phase-2-gated).
       `SwipePolicy`/`UserMatchPolicy` — both explicitly named in
       docs/06 §3.1 — cover self-swipe, block-either-direction,
       non-participant match access, and double-unmatch. `matches` uses
       `UserMatch` as the model class name (`match` is a PHP 8 reserved
       keyword, confirmed by `php -l` before committing to the name — cannot
       be used as a class name), table name overridden back to `matches` to
       stay schema-compliant. 112 backend tests (was 92), Pint + audit clean.
       **Mobile:** DiscoverFeedScreen (item 5) now has the real
       swipe-gesture card stack docs/07 §3.2 describes — drag left/pass,
       right/like, fly-away past a threshold or spring back short of it,
       Pass/Like buttons as the accessible non-gesture mirror (buttons skip
       the fly-away flourish and swipe instantly — a disclosed
       simplification, not a functional gap). A mutual like shows the match
       celebration modal ("Send a message" -> coming-soon at the time, since
       Chat was item 8 — wired to the real conversation once item 8 landed).
       New MatchesListScreen (`/matches`) covers just the matches
       half of docs/07 §3.3's "Matches + inbox" — the conversation list
       needed Chat too (superseded by `InboxScreen` in item 8). The Discover
       app bar's filter icon reuses the
       existing Edit preferences screen rather than a second, parallel
       filters UI; no boost icon — Phase 2, nothing behind it yet.
       Swipe-up-for-Super-Like isn't implemented, consistent with the
       backend's stance that Super Like's extras are [TBD-11]. 19 mobile
       tests passing (was 15), flutter analyze clean, `flutter build apk
       --debug` verified.
7. [x] Matching engine v1 (rule-based: preferences + interests overlap; **no AI score
       yet** — spec §10 explicitly defers the formula). Item 5's filters already
       covered "preferences"; this adds "interests overlap" as a *ranking* layer on
       top, in `DiscoveryFeedService`: candidates sort by `shared_interests_count`
       descending first, then the existing bucketed-distance/id tiebreakers. Per spec
       §10's explicit instruction ("do not hardcode a scoring algorithm in Phase 1;
       stub the field and revisit in Phase 4"), this is deliberately a plain,
       transparent count — never blended with other signals into one opaque
       "compatibility score." `shared_interests_count`/`shared_interests` (the actual
       names) are returned as-is in the feed response (docs/03), not hidden. "User
       behaviour" (also named in spec §10 as a matching input) isn't implemented —
       the spec never says what signal or algorithm that would mean, and guessing one
       would be exactly the kind of unstated specific CLAUDE.md says to flag, not
       invent. `compatibility_scores` (the Phase-4 AI table already reserved in
       docs/02) is untouched, as intended. 114 backend tests (was 112), Pint + audit
       clean. No mobile UI change needed — the ranking takes effect through the same
       `GET /discovery/feed` call DiscoverFeedScreen already makes; its domain model
       was updated to parse the two new fields for forward-compatibility, but nothing
       in docs/07's Card-stack wireframe calls for surfacing them visually, so no new
       UI was added.
8. [x] Real-time chat (text only), read receipts, typing indicator, online status —
       **Backend:** `laravel/reverb` installed (wasn't actually in composer.json
       despite docs/08 already documenting `reverb:start` — a Phase 0 gap, closed now)
       via `composer require laravel/reverb` + `php artisan install:broadcasting
       --reverb`. `conversations`/`messages` migrations; `GET /chat/conversations`,
       `GET/POST .../messages`, `PUT .../read` (all documented in docs/03, which only
       had a bare table before). `ConversationPolicy` (participant + not blocked,
       reused by both the REST endpoints and the `routes/channels.php` presence-channel
       authorizer). `SwipeService` (item 6) now also creates the `Conversation`
       alongside every `UserMatch`. Real-time delivery via `ShouldBroadcastNow` events
       (`NewMessageBroadcast`, `MessagesReadBroadcast`) on `presence-conversation.{id}`
       — typing indicator and online/offline are inherent to presence channels
       (member list + peer-to-peer client events), no REST endpoint needed for either.
       Unmatched-messaging gate (spec §12) enforced server-side, 403
       `subscription_required`, tested. `message_attachments` not built — text-only
       scope, no reader/writer for it yet (#16/17/18 unconfirmed). `ConversationResource`
       later gained `last_message_preview` for the inbox row. 127 backend tests (was
       114), Pint + audit clean. Verified beyond automated tests: booted a real
       `reverb:start` server and dispatched a real broadcast against it from `tinker`
       with no auth/connection error — the actual HMAC-signed publish round-trip
       works, not just "the event class fires" per `Event::fake()`.
       **Mobile:** `pusher_channels_flutter` was tried first and rejected — reading its
       native Android plugin showed it only ever calls `PusherOptions.setCluster(...)`,
       with no path to a custom host/port, so it's structurally incompatible with a
       self-hosted Reverb server. Switched to `pusher_reverb_flutter` (pure Dart, no
       native platform code) after reading its actual source to confirm the real API,
       not just its docs. New `lib/chat/` feature: `ChatRepository` (REST — inbox,
       history, send, read) and `ChatSocketService` (wraps the singleton
       `ReverbClient`, injects the Sanctum bearer token into the `POST
       /api/broadcasting/auth` handshake via a custom authorizer, exposes one
       `ConversationChannel` per open conversation with typed `onNewMessage`/
       `onMessagesRead`/`onTyping` streams and a `sendTyping()` whisper). `AppConfig`
       gained `reverbHost`/`reverbPort`/`reverbAppKey`/`reverbUseTls` +
       `reverbAuthEndpoint` (derived from `apiBaseUrl`, since the auth route lives
       outside the `/api/v1` prefix — see `backend/bootstrap/app.php`). `MatchesListScreen`
       was replaced by `InboxScreen` (docs/07 §3.3 "Matches + inbox": new-matches row +
       conversation list, sourced from `GET /chat/conversations` instead of `GET
       /matches`) and a new `ConversationScreen` (message bubbles, read receipt on the
       last own message, typing indicator, online header, composer — disabled with a
       banner when `requires_subscription_to_message` is true, since Phase 2's
       subscription purchase flow doesn't exist yet). No attachment button — voice
       note/photo/GIF stay [TBD-16/17/18]. The inbox deliberately doesn't hold a live
       socket per conversation just to sit in the list (pull-to-refresh + refresh on
       return instead); only the open conversation screen holds a channel. 33 mobile
       tests passing (was 19), flutter analyze + `dart format` clean, `flutter build
       apk --debug` verified (first feature pulling in a real WebSocket dependency).
9. [x] Push notifications (match, message, like) — **Backend:**
       `user_devices`/`notifications` migrations (docs/02 gained `fcm_token
       unique` and `notifications.created_at`, both undocumented gaps closed in
       this feature — see their table notes for why). `NotificationService`
       (provider-agnostic `PushSender`, mirroring the OTP feature's `SmsSender`
       — `LogPushSender` default locally, `FcmPushSender` for real delivery via
       FCM's HTTP v1 API + a service-account OAuth2 JWT-bearer flow, using
       `firebase/php-jwt` already installed for Apple Sign In). Always writes
       the `Notification` row first, then best-effort pushes to every
       registered device — a push failure never blocks or rolls back the
       swipe/match/message that triggered it. Hooked into `SwipeService`
       (new_match to both participants; like to the swiped-on user when it
       *doesn't* reciprocate) and `ChatController::sendMessage` (new_message to
       the other participant). The `like` notification deliberately carries no
       identity of the liker — "who liked me" stays [PROPOSED]/premium (Phase
       2); leaking it here would bypass that gate for free, same
       no-derivative-signal principle docs/06 §4 uses for location.
       `GET/POST /users/me/devices`, `DELETE /users/me/devices/{id}`
       (upserts by `fcm_token`, reassigning `user_id` if the same installation
       re-registers under a different account); `GET /notifications`,
       `PUT /notifications/{id}/read`, `PUT /notifications/read-all`. A
       follow-up fix caught while wiring mobile: the FCM `data` payload only
       ever carried `type`/`notification_id`, never the `conversation_id`/
       `match_id`/`other_user_id` the client actually needs to deep-link —
       now merges the stored `payload` in, stringified. 147 backend tests
       (was 127), Pint + audit clean. Not yet tested against a real Firebase
       project on this machine (none configured) — same "confirm before
       relying on this in production" status as `TwilioSmsSender`.

       **Mobile:** `firebase_core`/`firebase_messaging` added — initialized via
       `FirebaseOptions` built from `AppConfig`'s dart-defines, deliberately
       *not* `google-services.json` + the Gradle plugin, which fails the Android
       build outright without that file present; confirmed `flutter build apk
       --debug` still succeeds with no Firebase project configured at all. New
       `lib/notifications/` feature: `PushRepository` (registers/unregisters
       the FCM token against `/users/me/devices`, handles token rotation) and
       `NotificationTapGate` (wraps the app to show a SnackBar for a
       foreground push — Android suppresses the system tray while foregrounded
       — and deep-links a background/terminated tap: `new_match`/`new_message`
       -> that conversation, `like` -> the inbox, anything else -> nowhere, no
       screen exists for it). `/chat/:id` now also resolves a `Conversation`
       from just an id (`ConversationLoaderScreen`) for entry points — a
       tapped push, any future deep link — that don't already have the full
       object the way in-app navigation does. `NotificationPermissionScreen`
       (onboarding) now actually registers the device after the OS prompt,
       closing the gap flagged since item 2; `AuthController.signedOut()`
       unregisters it. No in-app "notification center" screen — docs/07's
       wireframe inventory never lists one (only a Settings sub-item for
       per-type toggles, itself not built), so `GET /notifications` has no
       mobile consumer yet; the OS notification tray is the whole UI for now,
       a disclosed scope choice, not a silent gap. Everything Firebase-facing
       degrades to a no-op rather than throwing, matching docs/07 §3.1's
       "denial is fine, app continues" for the permission prompt itself — no
       Firebase project is configured on this machine (docs/08), so none of
       it has been exercised against a real send; 41 mobile tests passing
       (was 33, all of them either pure routing-decision logic or the
       Firebase-absent no-op paths — see docs/08 for what's unverified),
       flutter analyze + dart format clean, `flutter build apk --debug`
       verified.
10. [x] Block / report / unmatch — **Backend:** Unmatch itself
       (`DELETE /matches/{id}`) already existed since item 6 — this feature's
       actual new work is Block and Report. `blocks`/`reports` had been
       schema-only (`Block` had no `#[Fillable]` — every prior use went
       through `Block::factory()`, which bypasses mass-assignment guarding
       entirely, so the gap only mattered once a real write endpoint needed
       it, now). New `Report` model/migration, `SafetyService`
       (`block`/`unblock`/`report`, both block/unblock idempotent — a repeat
       call succeeds rather than tripping `blocks`' own unique constraint).
       **Blocking also unmatches** (docs/07 §3.7): reuses the same
       soft-unmatch (`unmatched_at`/`unmatched_by`) `MatchController::destroy`
       uses, found by looking up an active `UserMatch` between the pair.
       `GET/POST /safety/block`, `DELETE /safety/block/{userId}`,
       `POST /safety/report` (`also_block` — docs/03 addendum, matching
       docs/07's "option to also block" — reuses `block()`),
       `GET /safety/report-categories`. `GET /safety/blocks` is also new
       (docs/03 addendum) — feeds docs/07 §3.7's "Blocked users" Settings
       screen, returning a null-safe projection (`BlockedUserResource`, not
       `MatchedUserResource` — you can block/report *any* user id, not just
       someone with a completed profile). Rate-limited 20/day/user on report
       (docs/06 §7). A follow-up fix caught while wiring mobile:
       `ChatController::index` never excluded a blocked conversation from
       the inbox listing itself (`ConversationPolicy::view` already 403'd
       opening one directly, but the list didn't know about blocks at all) —
       dormant until blocks could actually be written, so only surfaced now.
       170 backend tests (was 147), Pint + audit clean. Report evidence
       attachment ("attach which messages/photos", docs/07 §3.7) isn't
       built — the `reports` schema has no column for it, and inventing one
       wasn't asked for; flagged, not silently dropped.

       **Mobile:** new `lib/safety/` feature — `SafetyRepository` (block/
       unblock/report against the endpoints above) and a `ReportCategory`
       enum hardcoded client-side (same `SwipeDirection`/`MessageType`
       convention, not fetched from `GET /safety/report-categories`).
       `ConversationScreen` gained the header overflow docs/07 §3.3 always
       specified (Unmatch/Report/Block — "View profile" isn't built, no such
       screen exists for viewing another user outside a match/discovery
       card) — its own doc comment had claimed Unmatch was already wired
       there since feature 8, which wasn't actually true; fixed while adding
       the real menu. `ReportScreen` folds docs/07's "category" and "detail"
       screens into one screen with two internal steps, and "confirmation"
       into a `SnackBar` on the screen it pops back to — a disclosed
       simplification, not a dropped screen. New minimal `SettingsScreen`
       (only Privacy & Safety -> `BlockedUsersScreen`, and Log out, are
       real; every other Settings child — Account, Notifications toggles,
       Subscription, Help & Support, Legal, Delete account — is a
       coming-soon placeholder, each blocked on a feature that doesn't exist
       yet) replaces `MyProfileScreen`'s gear icon's old "Settings — coming
       soon" snackbar. Log out itself was a real, silent gap closed here —
       `AuthController.signedOut()` existed since Phase 0 but nothing in the
       app ever called it outside an automatic session-loss redirect. The
       Unmatch confirm dialog was extracted into a shared
       `showUnmatchConfirmDialog` (`InboxScreen` already had its own inline
       copy) so both call sites share one copy of the dialog text. 46
       mobile tests passing (was 41), flutter analyze + dart format clean,
       `flutter build apk --debug` verified.
11. [x] Admin panel v1 (Filament): user management, reports queue, basic dashboard —
       `composer require filament/filament` (landed on v5.8.1, the current stable
       major — requiring the caret range `^4.0` explicitly first hit a composer quirk
       where it treated that as pinning exactly `v4.0.0`, which composer's own
       advisory audit then refused outright, 7 open advisories against that one tag;
       dropping the version constraint and letting composer pick avoided the quirk
       and landed on the newer, unaffected major anyway). `AdminPanelProvider`: `/admin`, brand red
       `#DC2626`, and docs/06 §3.3's "mandatory 2FA (TOTP)" via Filament's *built-in*
       TOTP provider (`Filament\Auth\MultiFactor\App\AppAuthentication`,
       `isRequired: true`) — no third-party 2FA package needed, confirmed live
       (logged in as a fresh admin, got forced through the challenge, generated the
       code with `Google2FA` in tinker since there's no email/SMS channel to read it
       from in a test). `User` gained the Filament contracts this needs
       (`FilamentUser`/`canAccessPanel` gated to `admin`/`moderator` only,
       `HasAppAuthentication`/`HasAppAuthenticationRecovery`, `HasName` — the last one
       caught live, not by a test: Filament's account-menu widget hard-requires it and
       500s without one, since `users` has no `name` column) plus two new encrypted
       columns (`app_authentication_secret`/`app_authentication_recovery_codes`,
       docs/02, docs/06 §5 "critical" data class). New `audit_log` table (docs/02,
       docs/06 §8) + `App\Services\Admin\AuditLogger` as the one write path to it.
       `UserResource` (list/view only, no create/edit — admin doesn't hand-edit
       profile fields): search, status/role filters, and
       suspend/reinstate/ban/delete as custom actions through
       `AccountModerationService`, never a raw model update — each revokes every
       Sanctum token immediately and writes an audit row. Ban/delete are gated to
       `admin` only (docs/06 §3.3: moderators get "user suspend only") via
       `Gate::define('banUsers'|'deleteUsers', ...)`, checked *inside* the action
       closure (not just hidden from moderators in the UI) — same fail-closed
       discipline as every API policy. `ReportResource` (list only): mark
       actioned/dismiss through `ReportModerationService`, plus a combined "suspend
       reported user" action (suspends + marks actioned in one click, still two
       separate audited service calls under the hood). Server-side enforcement that
       "admin can suspend a user and it takes effect immediately" (this phase's own
       gate, below) needed three call sites that had *no* status check at all before
       this feature, found while implementing it, not by a report:
       `AuthController::tokenResponse` (suspended/banned can't log in, `403`
       `account_suspended`/`account_banned` — `deleted` never reaches this at all,
       already excluded by `SoftDeletes`' global scope), `DiscoveryFeedService`
       (excludes non-active candidates), `ConversationPolicy::sendMessage` (freezes
       an existing conversation read-only when *either* participant is
       suspended/banned, not just the suspended one's own send button). Dashboard:
       total/active/new-user, match, message, and pending-report counts — no
       premium-user/revenue cards, since `subscriptions` doesn't exist until Phase 2
       and a fake `0` would look like a working feature rather than an unbuilt one.
       14 new backend tests (170 -> 184: login rejection x2, discovery exclusion,
       conversation freeze, both moderation services, panel-access/gate/MFA-secret
       round-trip), Pint + `composer audit` clean. Verified beyond automated tests,
       live against a real browser session (this panel has no mobile-app UI, so
       there's no `flutter build` equivalent gate for it): admin login through the
       full TOTP challenge, dashboard stats against real seeded data, suspend ->
       reinstate on a real user record (confirmed the header actions swap and the
       `audit_log` row's `before`/`after` match), and the reports-queue "suspend
       reported user" action end-to-end. Not built: verification review and
       "suspicious accounts" (spec §19's Moderation bullet) — no verification
       pipeline exists yet (that's Phase 4); content moderation beyond the existing
       photo `moderation_status` (item 2) has no separate admin surface yet, nothing
       in scope names what it would additionally do. Report evidence attachment
       viewing stays flagged from item 10 (schema still has no column for it).
       Moderator-role restrictions (ban/delete hidden+refused) are covered by the
       `Gate` unit tests, not a second live login as a moderator — the gate itself is
       the actual control either way.

**Gate:** two people can register, complete onboarding, discover and match each other,
and chat in real time on a staging build; block/report work end to end; admin can
suspend a user and it takes effect immediately.

---

## Phase 2 — Premium (~3–4 weeks)

- [x] Subscription plans + purchase flow (App Store / Play Store or Stripe — per
      open decision #27). Asked before building: decision #27 is unresolved and
      materially changes what's testable here (native IAP needs real App Store
      Connect/Play Console accounts this machine doesn't have; Stripe has a test
      mode that needs none) — chose "build both, Stripe as the working default."
      **Backend:** `subscription_plans`/`subscriptions`/`payments` migrations
      (docs/02, unchanged from what it already specified). `PaymentGateway`
      interface (`LogPaymentGateway` default — activates instantly, same role as
      `LogSmsSender`/`LogPushSender`; `StripePaymentGateway` — real, calls
      Stripe's REST API via `Http` the same way `TwilioSmsSender`/
      `FcmPushSender` call theirs rather than pulling in `stripe/stripe-php`,
      not yet verified against a live account) and a separate `ReceiptVerifier`
      pair (`AppStoreReceiptVerifier`/`PlayStoreReceiptVerifier` — real-shaped,
      genuinely unconfigured, same status as Twilio/FCM) for native store
      billing, since the mobile client already knows which store it bought
      through rather than needing a server-side switch. `SubscriptionService`
      orchestrates both into one `activate()` (idempotent on
      `provider_subscription_id`, so a retried webhook or client retry can't
      double-create a subscription/payment pair). `POST /webhooks/stripe`
      (outside `/api/v1`, no Sanctum — the `Stripe-Signature` HMAC header is the
      entire authentication, `StripeWebhookSignatureVerifier`) handles
      `checkout.session.completed`/`customer.subscription.deleted`/
      `invoice.payment_failed`; **not** `invoice.payment_succeeded` extending
      `ends_at` on renewal, flagged as the natural fast-follow, not silently
      dropped. `User::isSubscriber()` — a hardcoded `return false` stub since
      Phase 1 (spec §16/§17) — is now real; every existing call site
      (`RateLimiter::for('swipes', ...)`, the chat unmatched-messaging gate)
      was already written against it, so flipping the stub was the entire
      integration for both, no call site changed. New `User::entitlement($key)`
      per docs/06 §3.4, deliberately **not** cached (that section describes an
      eventual Redis cache; skipped here — no Redis locally, and a cache keyed
      by user id is a real staleness hazard under `RefreshDatabase`'s per-test
      id reuse) — a plain query, correct and fast enough at this scale. Pricing
      (open decision #12: "not set") is never hardcoded anywhere — plans are
      fully data-driven (`subscription_plans.entitlements` jsonb), and the one
      seeded plan is explicitly commented as a local-dev/test placeholder, not
      a business figure. 44 new backend tests (184 -> 228: purchase flow via
      both paths, the full webhook lifecycle including replay-safety, both
      receipt verifiers, the signature verifier's edge cases, `isSubscriber`/
      `entitlement` truth table), Pint + `composer audit` clean.
      **Mobile:** new `lib/subscriptions/` feature — `SubscriptionRepository`
      (plans/me/purchase/cancel) always sends `provider: "stripe"`; new
      `PremiumScreen` lists plans or the active subscription, launches a
      returned `checkout_url` in the device browser via `url_launcher` (new
      dependency) when a real Stripe account is configured, otherwise the
      log-driver path activates instantly and the screen reflects it
      immediately — no deep-link handler exists yet to notice a completed
      browser payment automatically, so a manual pull-to-refresh is the
      recovery path, flagged not silently assumed away. Settings ->
      Subscription (a coming-soon placeholder since Phase 1 item 10, built
      specifically for this) now opens it. No native-store purchase UI — the
      backend endpoints exist but nothing in the app drives them yet, same
      disclosed-gap treatment as the Google/Apple sign-in buttons since
      onboarding. The chat "Subscribe to message people you haven't matched
      with" banner (item 8) is still plain text, not a tappable upgrade CTA —
      that's this phase's own item 4 ("adds ... the upgrade-prompt UX around
      it"), not this one's, kept as a deliberate scope boundary rather than
      blurring the two. 11 new mobile tests (46 -> 57: plan/subscription
      JSON mapping, all four purchase-response shapes, `isActive`'s status +
      expiry truth table), `flutter analyze` + `dart format` clean, `flutter
      build apk --debug` verified with `url_launcher` linked in.
- [x] Advanced filters unlocked/gated by plan. docs/01 §8 named religion and
      politics specifically ("build these as filterable fields on
      user_preferences, not as an afterthought") — `user_preferences` already
      had `religion_filter`/`politics_filter` (Phase 1 item 5), but `profiles`
      had nothing for a candidate to actually *have*, so the filter was
      structurally inert until now. **Backend:** new `profiles.religion`/
      `profiles.politics` (docs/02; free-form strings, same no-invented-
      taxonomy reasoning as the filter columns themselves) — free for anyone
      to set on their own profile via the existing `PUT /profiles/me`; never
      exposed on any resource another user can fetch (docs/07's Profile
      detail spec doesn't list them, and they're the kind of trait docs/06 §5
      treats as sensitive). `PreferenceController::update` enforces docs/06
      §3.4's already-written contract ("Premium filters ... 403 +
      error.code = upgrade_required") with one deliberate refinement: since
      `PUT /preferences/me` is a full replace (same as prompts), rejecting
      on "the field is non-empty" would lock a lapsed subscriber out of
      saving *any* preference change, including ones unrelated to advanced
      filters, the moment their old filter value got resent as a side effect
      of the form. Only an actual attempted *change* to a new value without
      the entitlement is rejected; resubmitting the exact stored value passes
      through. `DiscoveryFeedService` re-checks the entitlement independently
      at read time regardless of what's stored, so that's the real,
      authoritative gate either way — the write-time check is UX, not the
      control. 8 new backend tests (236 total), Pint + `composer audit`
      clean. **Mobile:** `EditBasicsScreen` gained religion/politics fields
      (free for everyone — the "advanced filters" screen's own doc comment
      explains the split). The existing "Advanced filters" section in
      Preferences (onboarding + Edit preferences) now checks the caller's
      current subscription (item 1's `SubscriptionRepository`): entitled ->
      unchanged; not entitled -> the *add* control locks with an "Upgrade"
      link straight to the Premium screen (item 1), while *removing* an
      already-set value (e.g. from a lapsed subscription) stays available,
      mirroring the backend's own change-vs-resubmit distinction exactly.
      Links to `PremiumScreen` directly rather than docs/07's more elaborate
      generic paywall-modal concept (benefit callout -> full benefit list ->
      plans) — a disclosed simplification, not a dropped screen, same
      treatment as several other hi-fi interaction details throughout this
      project. No dedicated widget test for the locked UI state itself
      (mirrors Phase 1 item 2's own "no per-screen widget tests" call) —
      the actual security boundary is the backend's, which is fully tested;
      2 new mobile tests for the repository-level data contract instead. All
      other mobile suites still green, `flutter analyze` + `dart format`
      clean, `flutter build apk --debug` verified.
- [ ] Unlimited likes, profile boost
- [ ] Unmatched messaging — **server-side gate is Phase-1 code**; this phase adds the
      subscriber check and the upgrade-prompt UX around it (spec §12)
- [ ] Subscription management in admin panel (plans, payments, status)
- [ ] Super Like / Rewind — **only if approved**, open decision #11

**Gate:** a non-subscriber is blocked (403, with a clean upgrade prompt) from every
premium action at the API layer, not just in the UI; a real (sandboxed) purchase
activates entitlements within a defined SLA (e.g. < 1 minute via webhook).

---

## Phase 3 — Communication (~2–3 weeks)

- [ ] Voice notes — if confirmed in scope (open decision #16)
- [ ] GIFs — if confirmed (open decision #17)
- [ ] Photo sharing in chat — if confirmed (open decision #18)
- [ ] Voice calling (WebRTC/Agora) — subscriber-gated (spec §13)
- [ ] Video calling — subscriber-gated

**Gate:** a call connects reliably across a real network (not just localhost/emulator);
call minutes are logged for support/analytics; non-subscribers are rejected server-side
at token issuance, not just blocked from the call button.

---

## Phase 4 — AI (~3–4 weeks)

- [ ] AI profile verification (photo/selfie pipeline — per chosen method, open
      decisions #21–23)
- [ ] Compatibility scoring (formula finalized with client before this phase starts —
      spec §10)
- [ ] Smart recommendations (`recommendation_history`)
- [ ] AI icebreakers — open decision #25

**Gate:** verification decisions are auditable (`verification_results` links every
approval/rejection to a model version or reviewer); compatibility scores are stable
(same inputs → same score) and explainable enough to support a customer-support query
("why was I shown this score?").

---

## Phase 5 — Production (~3–4 weeks)

- [ ] Security audit (auth flows, rate limits, PII handling, dependency scan)
- [ ] Performance/load testing (discovery feed and chat are the hot paths)
- [ ] App Store submission prep (screenshots, privacy nutrition label, review notes)
- [ ] Play Store submission prep
- [ ] Production deployment (infra matches `02-database-schema.md` + the operating-cost
      assumptions in `/proposal`)
- [ ] Monitoring/error tracking wired to alert on-call, not just log
- [ ] Automated database backups verified with a real restore test
- [ ] Analytics events instrumented for the admin dashboard's metrics

**Gate:** a full incident-response dry run (simulate a failed deploy or a DB restore)
succeeds; both store submissions are accepted or in review; monitoring has fired at
least one real test alert end-to-end.

---

## Timeline summary

| Phase | Duration |
|---|---|
| 0 — Architecture & Design | 3–5 weeks |
| 1 — MVP | 6–8 weeks |
| 2 — Premium | 3–4 weeks |
| 3 — Communication | 2–3 weeks |
| 4 — AI | 3–4 weeks |
| 5 — Production | 3–4 weeks |
| **Total** | **20–28 weeks** |
