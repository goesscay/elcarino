# CLAUDE.md — working instructions for this repo

This file tells Claude Code **how** to work in `C:\DatingApp`. For **what** is being
built, read [`docs/00-overview.md`](docs/00-overview.md) and the documents it links to
— don't re-derive scope from memory of the chat; the docs are the source of truth and
may have moved on.

## Repo layout

```
/proposal    client-facing deliverables (proposal deck, cost deck) — do not edit for dev work
/docs        engineering specification — the source of truth for scope
/mobile      Flutter app
/backend     Laravel API
```

## The one rule that matters most

**Build one feature at a time, in the order [`docs/04-development-phases.md`](docs/04-development-phases.md)
lays out, and don't start the next feature until the current one clears its gate:**

```
read spec → implement → write tests → self-review the diff → fix issues found → commit
```

Do not attempt to scaffold the whole app in one pass. A session that tries to build
auth, profile, discovery, and chat all at once produces code nobody — including the
next Claude session — can verify. One feature, fully working and tested, beats four
half-built ones.

Do not start Phase *N+1* work while Phase *N*'s gate (checklist in
`04-development-phases.md`) is still unmet, even if it would be technically easy to
jump ahead — the gates exist because later phases assume earlier ones are solid
(e.g. Phase 2's subscriber-gating assumes Phase 1's chat and matching already work).

## Handling open decisions

[`docs/05-open-decisions.md`](docs/05-open-decisions.md) tracks 30 unresolved
business/product decisions. Code that depends on one of them carries a `// TBD-#`
(Dart) or `// TBD-#` (PHP) comment next to the assumption, matching the doc's numbering.

- **Do** implement the stated working assumption so development isn't blocked.
- **Don't** silently narrow an assumption into something more specific than the doc
  says (e.g. don't invent a price, a legal disclaimer, or a fourth gender option not
  listed) — that's a decision, not an implementation detail.
- If a task can't proceed sensibly without an answer (rare — most have a stated
  default), say so and ask, rather than guessing at business-critical specifics like
  pricing or legal copy.

## Backend conventions (Laravel / PHP 8.3+)

- Migrations mirror [`docs/02-database-schema.md`](docs/02-database-schema.md) exactly
  — column names, types, and enum values. If a migration needs to diverge, update the
  doc in the same commit.
- **Local dev DB is SQLite; staging/prod is PostgreSQL.** Write migrations portably
  (`$table->json()` not raw `jsonb`, `$table->double()` for coordinates,
  `$table->enum()` for enums). Anything Postgres-specific (geohash proximity queries,
  `jsonb` operators) goes behind a repository method and is verified in staging.
- Every mutating endpoint: **Form Request** for validation, **Policy** for
  authorization, **API Resource** for the response shape. No raw Eloquent models
  returned from controllers.
- Server-side enforcement is non-negotiable for the rules called out in
  `docs/01-technical-specification.md` — unmatched-messaging subscriber gate (§12) and
  the calls subscriber gate (§13) must reject at the API layer (403), never rely on the
  mobile app hiding a button.
- Geolocation: `user_locations` stores exact coordinates; every response to a client
  carries only a rounded/bucketed distance (spec §9). Never serialize raw lat/long
  into an API Resource that a non-owner can see.
- Tests: Pest or PHPUnit, one feature test per endpoint at minimum (happy path +
  the primary authorization failure). Run `php artisan test` before calling a backend
  task done.

## Mobile conventions (Flutter)

- Feature-first + Clean Architecture per `docs/01-technical-specification.md` §4:
  every feature under `lib/<feature>/{presentation,domain,data}/`. Shared code only in
  `lib/core/`.
- State management: **Riverpod** (confirmed). Do not introduce a second state pattern
  anywhere. Shared providers in `lib/core/`; feature-local providers under the
  feature's `presentation/`.
- Networking goes through a single typed API client in `core/` that mirrors
  [`docs/03-api-specification.md`](docs/03-api-specification.md) — if you add a call the
  spec doesn't have, add it to the spec in the same commit.
- Widget/unit tests alongside new presentation/domain code. Run `flutter test` before
  calling a mobile task done.

## Commits

- One commit per completed, tested feature/task — not one commit per file, not one
  giant commit per phase.
- Conventional-ish messages: `feat(auth): phone OTP login`, `fix(chat): read receipts
  not marking on scroll`, `docs: update open-decisions #10`.
- Update the relevant `docs/` file in the same commit when a decision changes scope,
  schema, or an endpoint — the docs must never silently drift behind the code.

## Environment notes

- Windows 11, PowerShell is the primary shell; the Bash tool is also available but
  uses POSIX syntax — don't mix syntaxes in one command.
- Flutter SDK is at `C:\Users\user\flutter` (not on the global PATH by default —
  prefix `C:\Users\user\flutter\bin\flutter` or add it to PATH for the session).
  Composer works from PowerShell; from the Bash tool it isn't on PATH.
- CI workflows exist (`.github/workflows/`) but **there is no git remote yet** — they
  don't run. Until a remote is added, "`php artisan test` / `flutter test` +
  analyze/lint pass locally" is the bar for a task being done.
- Local dev DB is SQLite; no Redis, Docker, or Android SDK installed yet. Full setup
  state is in [`docs/08-environment-setup.md`](docs/08-environment-setup.md).
