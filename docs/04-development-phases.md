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
- [ ] UI/UX design (wireframes → high-fidelity, per screen, matching the module list in
      the technical spec)
- [ ] Security architecture review (auth flow, token lifetimes, PII handling, the
      server-side enforcement points called out in spec §12/§13)
- [ ] Resolve enough of [`05-open-decisions.md`](05-open-decisions.md) to unblock
      Phase 1 specifically: app name/branding, gender options, age range policy,
      state-management choice (Riverpod/Bloc), SMS provider
- [ ] Repo, CI skeleton, environment config (`.env.example` for backend, Flutter
      flavors for dev/staging/prod)
- [ ] Laravel project scaffolded in `/backend`, Flutter project scaffolded in `/mobile`

**Gate:** design signed off; `/backend` boots locally with migrations from
`02-database-schema.md` applied; `/mobile` boots to a placeholder home screen.

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
