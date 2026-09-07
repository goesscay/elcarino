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
      **Still open (do not block Phase 1):** app name/branding (#2, staying on
      placeholder `DatingApp` / `com.mgs.datingapp`), SMS/OTP provider (Phase 1 builds
      a provider-agnostic sender, default impl Twilio).
- [x] Repo, CI skeleton, environment config — `.gitattributes`,
      `.github/workflows/{backend,mobile}.yml`, `backend/.env.example` (all integration
      keys documented), `mobile/config/{dev,staging,prod}.json` + `AppConfig`,
      `docs/08-environment-setup.md`.
- [x] Laravel scaffolded in `/backend` (Laravel 13, SQLite local dev) — boots,
      migrates, `php artisan test` + Pint green. Flutter scaffolded in `/mobile`
      (Flutter 3.47.2, Riverpod, go_router, feature-first folders, themed placeholder
      home) — `flutter analyze` + `flutter test` green, **and `flutter build apk
      --debug` produces a valid `com.mgs.datingapp` APK** (JDK 17 + Android SDK 36
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

1. [ ] Authentication (email, phone+OTP, Google, Apple; logout, forgot password)
2. [ ] Onboarding flow (account → profile basics → photos → prompts → preferences)
3. [ ] Profile module (view/edit, photo upload + reorder + moderation queue)
4. [ ] Profile prompts (library + answer + reorder)
5. [ ] Discovery feed (filters, radius, exclude swiped/blocked)
6. [ ] Swipe → like/pass → match
7. [ ] Matching engine v1 (rule-based: preferences + interests overlap; **no AI score
       yet** — spec §10 explicitly defers the formula)
8. [ ] Real-time chat (text only), read receipts, typing indicator, online status
9. [ ] Push notifications (match, message, like)
10. [ ] Block / report / unmatch
11. [ ] Admin panel v1 (Filament): user management, reports queue, basic dashboard

**Gate:** two people can register, complete onboarding, discover and match each other,
and chat in real time on a staging build; block/report work end to end; admin can
suspend a user and it takes effect immediately.

---

## Phase 2 — Premium (~3–4 weeks)

- [ ] Subscription plans + purchase flow (App Store / Play Store or Stripe — per
      open decision #27)
- [ ] Advanced filters unlocked/gated by plan
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
