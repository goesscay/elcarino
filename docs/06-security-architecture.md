# Security Architecture

Phase 0 deliverable. Establishes the security bar every feature is built to. Companion
to [`01-technical-specification.md`](01-technical-specification.md) §20 (non-functional
requirements) — this document expands that section into an actionable model.

Nothing here is optional. If a feature can't meet these constraints, that's a blocker
to raise, not a corner to cut.

---

## 1. Threat model — what we're defending against

A dating app's risk profile is dominated by **harm to users from other users**, not
just classic web-app attacks. Ranked by likely impact:

| Threat | Vector | Primary mitigations |
|---|---|---|
| **Location stalking** | Attacker infers a target's home/movements from distance data | Coordinates never leave the server; distance bucketed (§4); no "distance decreasing" signals |
| **Catfishing / fake profiles** | Stolen or AI-generated photos | Photo moderation queue (§6); verification pipeline (spec §15); report → review loop |
| **Harassment** | Unwanted contact, abusive messages | Block (hard, mutual invisibility); report; unmatch; unmatched-messaging gate (§3.4) |
| **Account takeover** | Credential stuffing, OTP interception, session theft | Rate-limited auth (§7); short-lived single-use OTP; token revocation on password change; device list |
| **Payment fraud / abuse** | Fake receipts, chargeback farming, refund abuse | Server-side receipt validation; webhook signature verification; entitlement changes only via verified provider events |
| **Scraping** | Bulk harvesting of profiles/photos for resale or a competing app | Auth required for every profile view; per-user swipe/feed rate limits; signed expiring media URLs |
| **PII disclosure** | Over-serialized API responses, verbose errors, logs | API Resources only (never raw models); consistent error envelope with no stack traces in prod; PII scrubbing in logs (§5) |
| **Minor safety** | Under-18 users | 18+ gate at signup via `birth_date` (open decision #4); report category + fast-track moderation |
| **CSAM / illegal content** | Uploaded to photos or chat | Moderation queue before visibility; provider-side scanning where available; legal-hold + reporting process (§9) |

---

## 2. Authentication

### 2.1 Token model

- **Laravel Sanctum** personal access tokens, one per device.
- **Access token lifetime:** short — 60 minutes. **Refresh:** a separate long-lived
  refresh token (30 days, single rotation on use — using a refresh invalidates it and
  issues a new pair). Store refresh tokens hashed.
- **Revocation triggers** (all tokens for the user are revoked): password change,
  password reset, account suspension/ban, explicit "log out everywhere",
  user-initiated device removal.
- Tokens are bound to a `user_devices` row; a token with no matching active device is
  rejected even if not expired.

### 2.2 OTP (phone verification + phone login)

- 6-digit numeric, generated with a CSPRNG, **hashed** at rest (never stored plaintext).
- TTL: 5 minutes. **Single use** — consumed on first successful verify.
- Max 5 verify attempts per code, then the code is burned and a new request is required.
- Request throttle: 1 per 60s per phone number, 5 per hour per phone number, 20 per
  hour per IP.
- OTP delivery provider is open decision #5-adjacent (SMS provider) — whatever is
  chosen, the provider API key lives only in `.env`, and delivery failures are logged
  without the code value.

### 2.3 OAuth (Google, Apple)

- Verify the ID token **server-side** against the provider's JWKS on every login — never
  trust a token the client says is valid.
- Match on the provider `sub` claim stored in `users.google_id` / `users.apple_id`, not
  on email (email can change / be unverified).
- Apple: honour "Hide My Email" — store the relay address; never require a real email.
- Account linking (same person, Google + phone): allowed, but only after verifying
  control of both identifiers.

### 2.4 Password storage

- Laravel default hashing (bcrypt, cost ≥ 12, or argon2id). Never MD5/SHA.
- Password nullable in `users` — OAuth-only accounts have no password and cannot use
  the password-login path.

---

## 3. Authorization

### 3.1 Model

- **Roles** (`users.role`): `user`, `moderator`, `admin`. Roles are coarse; fine-grained
  checks are per-resource.
- **Policies** on every model with owner-scoped access (`ProfilePolicy`,
  `ConversationPolicy`, `SwipePolicy`, …). Controllers call `$this->authorize(...)` —
  no ad-hoc `if` checks scattered in controller bodies.
- **Default deny:** a route with no explicit policy/gate is treated as a bug, caught in
  code review.

### 3.2 Ownership rules

- A user may read/write only their own `profile`, `preferences`, `prompts`, `photos`,
  `devices`, `location`, `notifications`, `payments`.
- A user may read another user's **public profile projection** only if: not blocked in
  either direction, and (for full profile) they have an active match OR the target
  appears in the requester's current discovery feed.
- Messages: a user may read/write a `conversation` only if they are one of its two
  participants and neither has blocked the other.

### 3.3 Admin / moderator

- Admin panel (Filament) is a separate authenticated surface — admin login is **not**
  the mobile Sanctum flow; it uses session auth with mandatory 2FA (TOTP).
- Moderators: reports queue + verification review + user suspend only. Cannot delete
  users, cannot touch subscription/payment data, cannot change plans.
- Admin: everything, but every destructive or state-changing admin action is
  audit-logged (§8).

### 3.4 Server-side enforcement points (non-negotiable)

These rules are enforced in the API layer and **fail closed**. The mobile app also
hides the relevant UI, but that is defence-in-depth, never the control:

| Rule | Enforced at | Failure response |
|---|---|---|
| Messaging an **unmatched** user requires an active subscription (spec §12) | `POST /chat/conversations/{id}/messages` policy check | `403` + `error.code = "subscription_required"` |
| Voice/video **call token** issuance requires an active subscription (spec §13) | `POST /calls/token` policy check | `403` + `error.code = "subscription_required"` |
| Premium filters / unlimited likes / boost / who-liked-me | respective endpoints check `user->entitlement(...)` | `403` + `error.code = "upgrade_required"` |
| Under-18 signup | registration Form Request validates age from `birth_date` | `422` |

`user->isSubscriber()` and `user->entitlement($key)` read from the `subscriptions` +
`subscription_plans.entitlements` join, cached in Redis with a short TTL and busted on
any subscription state change (webhook, cancel, expiry job).

---

## 4. Geolocation privacy

- `user_locations` stores exact `latitude`/`longitude` + a `geohash`. This table is
  **never** exposed through an API Resource that another user can retrieve.
- Every distance shown to a client is **bucketed**: `< 1 km` → `"less than 1 km away"`;
  otherwise rounded to the nearest km (or nearest 5 km beyond 30 km). The raw float is
  never serialized.
- No derivative signals that leak precision: no "getting closer" notifications, no
  distance in push payloads, no sorting the feed by exact distance in a way that lets a
  client binary-search a location by repeatedly changing its own.
- Location updates are rate-limited (max 1 stored update / 5 min / user) and the client
  sends coarse coordinates (≤ 3 decimal places, ~100 m) — the app does not upload GPS
  fixes.
- A user can operate with location disabled (falls back to a city/region they set
  manually); the app must degrade gracefully, not block.

---

## 5. Data classification & handling

| Class | Examples | Rules |
|---|---|---|
| **Critical** | Verification photos/IDs, payment tokens/PANs, exact coordinates, OTP/refresh secrets | Encrypted at rest; access logged; excluded from every log sink; shortest viable retention; never in analytics events |
| **Sensitive** | Messages, phone, email, DOB, `interested_in_genders`, religion/politics filters | TLS in transit; not logged; not in analytics beyond aggregate counts; served only to owner/authorized parties |
| **Internal** | Display name, bio, photos (post-moderation), interests, prompt answers | Visible to authorized viewers per §3.2; still not logged verbatim |
| **Public-ish** | Interest catalogue, prompt library, subscription plan list | Cacheable, unauthenticated GET allowed |

- **Logging:** structured logs only; a PII-scrubbing processor strips
  email/phone/coords/tokens/message bodies before any log leaves the process. Sentry
  configured with `send_default_pii = false` and a `before_send` scrubber.
- **Analytics:** event names + counts + non-identifying dimensions only. No message
  content, no coordinates, no contact info. (Analytics is open decision #-adjacent; the
  constraint applies whatever tool is chosen.)

---

## 6. Media security

- Uploads validated server-side: MIME sniff (not trust the extension), max dimensions,
  max file size, re-encode to strip EXIF (**GPS EXIF stripping is mandatory** — a photo
  with embedded coordinates defeats §4).
- Stored in a **private** S3-compatible bucket. Served only via **signed URLs** with a
  short expiry (minutes for chat media, longer but still bounded for profile photos).
- `profile_photos.moderation_status` gates visibility: a `pending` photo is visible
  only to its owner until `approved`.
- Chat attachments (`message_attachments`) inherit the conversation's authorization —
  a signed URL is minted per request for a participant, never a stable public link.

---

## 7. Rate limiting & abuse controls

| Surface | Limit (starting point — tune with real data) |
|---|---|
| `auth/login` | 5 / min / IP, 10 / hour / account |
| `auth/otp/request` | see §2.2 |
| `swipes` | 100 / hour / user (free), higher for subscribers; hard ceiling regardless of tier to blunt scripted scraping |
| `discovery/feed` | 60 / hour / user |
| `chat/messages` send | 30 / min / conversation, 300 / hour / user |
| `safety/report` | 20 / day / user (a user reporting dozens of people per hour is itself a signal) |
| `profiles/{userId}` view | 300 / hour / user |

- Limits return `429` with a `Retry-After` header and the standard error envelope.
- Repeated 429s from one account raise an abuse flag visible in the admin panel.

---

## 8. Audit logging

An append-only `audit_log` table (add to
[`02-database-schema.md`](02-database-schema.md) when the admin panel is built) records:

- Every admin/moderator action: who, what, target, before/after where applicable, when.
- Every moderation decision (report actioned/dismissed, verification approved/rejected).
- Every account status change (suspend, ban, reinstate, delete).
- Security-relevant auth events: password reset, "log out everywhere", new device
  registered, OAuth account linked.

Audit rows are never editable or deletable through the app, including by admins.

---

## 9. Account lifecycle & content takedown

- **Suspend:** user cannot log in; existing tokens revoked; profile hidden from
  discovery; existing conversations frozen (read-only). Reversible.
- **Ban:** as suspend, permanent; content retained for the legal-hold window then
  purged.
- **User-initiated deletion:** soft-delete immediately (`users.deleted_at`), profile
  and photos removed from all discovery/chat surfaces within seconds; a background job
  performs hard deletion / anonymization after the retention window
  (jurisdiction-dependent — see §11), preserving only what law requires (e.g.
  transaction records, abuse-report evidence about *other* users).
- **CSAM / illegal content:** immediate removal, account ban, evidence preserved under
  legal hold, report filed with the relevant authority/NGO per the operating
  jurisdiction. This process is documented and owned before launch, not improvised.

---

## 10. Transport, secrets, dependencies, infrastructure

- **Transport:** TLS 1.2+ only; HSTS; HTTP redirects to HTTPS; no mixed content.
  Consider certificate pinning in the mobile app for the API host (revisit in Phase 5).
- **Secrets:** only in `.env` (backend) / secure CI secrets / platform secret manager
  in prod. `.env` is git-ignored; `.env.example` carries keys with empty/placeholder
  values only. `APP_KEY` and any signing keys are per-environment and rotated on a
  defined schedule; rotation procedure is documented.
- **Dependencies:** `composer audit` (backend) and `dart pub outdated`/OSV scanning
  (mobile) run in CI; a failing advisory scan fails the build. Dependabot/Renovate once
  a remote exists.
- **Infrastructure:** database not publicly reachable (private network / VPC only);
  Redis password-protected and not public; object storage bucket private with no
  list permission; least-privilege IAM for the app's storage credentials.
- **Backups:** automated, encrypted, tested with a real restore (Phase 5 gate).

---

## 11. Compliance — flagged, not solved

Launch markets have distinct data-protection regimes. These need a compliance/legal
owner (open decision #29-adjacent; budget line "Legal / Privacy / Compliance" in the
cost deck). Engineering commitments that make compliance tractable are already baked in
above:

| Market | Regime (as of this writing — verify with counsel) | Engineering hooks already in place |
|---|---|---|
| Malaysia (launch) | PDPA 2010 (+ 2024 amendments) | Consent capture at onboarding; data export/delete jobs; breach-notification-ready audit log |
| Maldives | Evolving data-protection framework | Same hooks; data-residency question to confirm before Maldives rollout |
| India | DPDP Act 2023 | Consent + purpose limitation; data-principal rights (access/correction/erasure) served by the same export/delete jobs; children's-data provisions reinforce the 18+ gate |

- Build a **data export** endpoint (user downloads their data) and ensure the
  **deletion** job is genuine erasure/anonymization, from Phase 1 — retrofitting these
  is expensive.
- Privacy policy / ToS / consent copy is **legal work, not engineering** (and a `[TBD]`
  — do not let Claude Code draft binding legal text; wire up the screens with
  placeholder links).

---

## 12. Security review gates per phase

| Phase | Security check before the gate passes |
|---|---|
| 1 — MVP | Auth flows pen-tested (OTP brute force, token replay, IDOR on profile/conversation); default-deny verified on every route; geolocation responses inspected for coordinate leakage |
| 2 — Premium | The §3.4 enforcement points independently verified server-side with a non-subscriber token; webhook signature verification tested with a forged payload |
| 3 — Communication | Call token cannot be obtained by a non-subscriber or a non-participant; chat media URLs expire and are not guessable |
| 4 — AI | Verification decisions auditable; AI provider receives only the minimum necessary data; model inputs/outputs for verification retained per §5 retention rules |
| 5 — Production | Full dependency audit clean; secrets scan of the repo history clean; restore test passed; monitoring alerts fire; incident-response dry run completed |
