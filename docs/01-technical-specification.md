# Technical Specification

Internal engineering specification. Companion to [`00-overview.md`](00-overview.md);
schema lives in [`02-database-schema.md`](02-database-schema.md), endpoints in
[`03-api-specification.md`](03-api-specification.md), phasing in
[`04-development-phases.md`](04-development-phases.md).

## 1. Product Vision

Build a modern dating application focused on: meaningful connections, profile
authenticity, smart matching, location-based discovery, secure communication, user
safety, premium features, and future AI-powered capabilities.

The application must **not** be a direct visual or functional copy of Tinder/Bumble —
its own branding, UI/UX and product identity. Positioning targets a distinct
niche/community **[TBD-1]** rather than competing head-on with large dating platforms.

**Launch markets:** Malaysia first, then the Maldives and India (phased rollout).

## 2. Technology Stack

| Component | Technology |
|---|---|
| Mobile | Flutter |
| Backend | Laravel 12 |
| Language | PHP 8.3+ |
| Database | PostgreSQL |
| Cache | Redis |
| API | REST API |
| Authentication | Laravel Sanctum + OAuth |
| Real-time | Laravel Reverb / WebSockets |
| Media storage | S3-compatible object storage |
| Push notifications | Firebase Cloud Messaging |
| AI | OpenAI API |
| Voice / video | WebRTC or Agora **[TBD]** — final provider confirmed before Phase 3 |
| Maps | Google Maps or Mapbox **[TBD]** |
| Admin panel | Laravel + Filament |
| Containerization | Docker |
| Version control | Git (this repo) |
| CI/CD | GitHub Actions (once a remote is provisioned) |
| Monitoring | Sentry or equivalent application monitoring |
| Web server | Nginx |

## 3. System Architecture

```
                    ┌──────────────────┐
                    │      USERS       │
                    │  Android / iOS   │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │   FLUTTER APP    │
                    └────────┬─────────┘
                             │  HTTPS / WebSocket
                             ▼
              ┌──────────────────────────────┐
              │         LARAVEL API           │
              │  Auth · Profiles · Discovery  │
              │  Matching · Chat · Subscript. │
              │  Safety · AI Integration      │
              └──────────────┬─────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
 ┌─────────────┐       ┌─────────────┐       ┌──────────────┐
 │ PostgreSQL  │       │    Redis    │       │ Object store │
 │             │       │             │       │ (photos etc) │
 └─────────────┘       └─────────────┘       └──────────────┘
                              │
                ┌─────────────┼─────────────┐
                ▼             ▼             ▼
               AI      Notifications     Realtime
          (OpenAI API)     (FCM)      (Reverb / WS)
```

Every API request/response passes through: authentication → authorization → request
validation → API resource transformation → rate limiting → a consistent error envelope.
See [`03-api-specification.md`](03-api-specification.md) §"Cross-cutting standards".

## 4. Mobile Application Structure

Feature-first + Clean Architecture. Each feature module owns its own
`presentation / domain / data` layers so it can be built, tested, and shipped
independently, phase by phase.

```
lib/
├── core/            shared utilities, theming, networking, DI, routing
├── authentication/
├── onboarding/
├── profile/
├── discovery/
├── matching/
├── chat/
├── notifications/
├── subscriptions/
├── verification/
├── calls/
├── safety/
└── settings/
```

Within a feature module:

```
feature_x/
├── presentation/   widgets, screens, state (Bloc/Riverpod — pick one, see below)
├── domain/         entities, use cases, repository contracts
└── data/           API clients, DTOs/models, repository implementations
```

**State management [TBD]:** not yet chosen (e.g. Riverpod vs Bloc). Recommendation:
Riverpod for a feature-first codebase built incrementally by an AI-assisted workflow —
less boilerplate per feature, easier to scaffold one module at a time. Confirm before
Phase 1 so `core/` DI wiring is consistent across every feature from the start.

## 5. Authentication — **[REQUIRED]**

- Email login
- Phone number login
- OTP verification
- Google login
- Apple login

Additional, proposed **[PROPOSED]**: logout, forgot password, account deletion, session
management, device management.

Backend: Laravel Sanctum for token issuance; OAuth providers (Google/Apple) via
Socialite or equivalent. OTP delivery via the SMS provider chosen for Phase 1
(see [`02-database-schema.md`](02-database-schema.md) `user_devices`, and cost item
"SMS / OTP" in the operating-costs deck).

## 6. Profile Module — **[REQUIRED]**

A basic profile engine: photos, short bio, and preferences such as age, distance and
hobbies. Editable fields:

- Profile photo + additional photos
- Name, age, bio
- Hobbies, interests
- Dating preferences, distance preference, relationship goals

## 7. Profile Prompts — **[PROPOSED]**

A dedicated prompt system for personality signal beyond photos:

- Curated library of prompts by category (`profile_prompts`)
- Members select and answer multiple prompts (`user_profile_prompts`)
- Answers displayed on the profile, re-orderable

Example prompts: *"I feel most like myself when…"*, *"My ideal first date is…"*,
*"A green flag I look for is…"*, *"My perfect weekend is…"*.

## 8. Discovery Module — **[REQUIRED]**

Core loop: `Profile → swipe left (PASS) / swipe right (LIKE) → mutual like → MATCH`.

**Initial filters [REQUIRED]:** age, distance, interests, relationship goals.
**Advanced filters [REQUIRED]:** religion, politics, additional preferences (explicitly
called out by the client — build these as filterable fields on `user_preferences`, not
as an afterthought).

## 9. Geolocation — **[REQUIRED]**

Discovery is prioritized/restricted by a selected distance radius
(`User location → distance radius → candidate profiles → matching filters → discovery`).

**Privacy — mandatory:**
- Never expose exact coordinates, exact address, or raw GPS data to other users.
- Display approximate information only, e.g. *"4 km away"*.
- Store precise coordinates server-side (`user_locations`); compute and serve only the
  rounded/bucketed distance to clients.

## 10. Matching Engine — **[REQUIRED]** core, **[PROPOSED]** scoring

Matching considers: preferences, interests, user behaviour, relationship goals,
location. A compatibility score (e.g. *"91% Compatible"*) is a **future/AI** capability
— exact formula and weightings to be finalized with the client before implementation
(do not hardcode a scoring algorithm in Phase 1; stub the field and revisit in Phase 4).

## 11. Like / Pass / Match — **[REQUIRED]** core, **[PROPOSED]** extras

Core: Like, Pass, Match, Unmatch.
Proposed premium/engagement, not mandatory MVP unless approved **[TBD-11]**: Super Like,
Rewind.

## 12. Chat Module — **[REQUIRED]**

Once matched: real-time text chat, message history, read receipts, typing indicator,
online/offline status, push notifications. Low-latency delivery is an explicit client
requirement — build on Laravel Reverb/WebSockets, not polling.

**Media communication — confirm as MVP or Phase 2 [TBD-16/17/18]:** voice notes, GIFs,
photo sharing.

### Unmatched messaging — mandatory business rule

Messaging an unmatched user is **restricted to subscription users**. This rule **must
be enforced server-side** (API authorization check on the message-send endpoint), not
only hidden in the mobile UI. See [`03-api-specification.md`](03-api-specification.md)
`POST /api/v1/chat/conversations/{id}/messages`.

## 13. Voice & Video Calling — **[PROPOSED]**, subscriber-only

Subscriber-only feature. Technology: WebRTC, Agora, or another approved provider
**[TBD-19/20]**. Gate: `Match → subscriber? → yes: voice/video, no: upgrade prompt`
(same server-side-enforcement rule as unmatched messaging applies).

## 14. Safety & Moderation — **[REQUIRED]**

Mandatory: block, report, unmatch, abuse reporting, user moderation.

Proposed report categories **[PROPOSED]**: Harassment, Fake profile, Spam,
Inappropriate content, Scam, Other.

## 15. Profile Verification — **[PROPOSED]**

Flow: `verification request → photo/selfie prompt → AI verification → result →
verified badge`. Reduces catfishing. Exact provider and methodology — AI, manual
review, or ID verification **[TBD-21/22/23]** — confirmed before implementation;
`verification_requests` / `verification_results` are designed to support any of the
three without a schema change.

## 16. Subscription System — **[PROPOSED]**

**Free:** profile creation, discovery, basic filters, like/pass, matching, basic
messaging.
**Premium:** unlimited likes, advanced filters, profile boost, message unmatched
users, voice calling, video calling.

Number of plans, pricing, and exact entitlements: **[TBD-11/12/13/14/15]**. Schema
(`subscription_plans`, `subscriptions`) supports N plans with a JSON entitlements
column so pricing/plan changes don't require migrations.

## 17. Gamification — **[PROPOSED]**

Profile prompts, badges, swipe mechanics, profile completion, engagement achievements.

## 18. Notification System — **[REQUIRED]**

Events: new match, new message, like, subscription, verification, report status,
system announcements. Delivery: Firebase Cloud Messaging.

## 19. Admin Panel — **[REQUIRED]**

- **Dashboard:** total/active/new users, matches, messages, reports, premium users, revenue.
- **User management:** search, view, suspend, ban, delete.
- **Moderation:** reports queue, verification review, suspicious accounts, content moderation.
- **Subscription:** plans, users, payments, subscription status.

Built with Laravel + Filament so admin CRUD/dashboards ship fast without a bespoke
frontend.

## 20. Non-functional requirements

Not explicitly itemized in the client's requirements but implicit in "secure
communication" and "user safety" — treat as baseline engineering bar, not optional:

- All endpoints behind authentication + authorization checks by default (deny unless allowed).
- Rate limiting on auth, OTP, swipe, and message-send endpoints to blunt abuse/scraping.
- PII (exact location, verification photos, payment tokens) never logged in plaintext.
- Passwords hashed (bcrypt/argon2 via Laravel default); OTPs short-lived and single-use.
- Media uploads validated (type, size) and served via signed/expiring URLs, not public buckets.
- Every migration is reversible; every destructive admin action is audit-logged.
