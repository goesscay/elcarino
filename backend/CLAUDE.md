# backend/ — Laravel-specific working notes

The repo-wide rules are in [`../CLAUDE.md`](../CLAUDE.md) — read that first. This file
only adds Laravel/PHP specifics for work under `backend/`.

## Stack

- Laravel 13 · PHP 8.3 · Sanctum (API auth) · Filament (admin) — see
  [`../docs/01-technical-specification.md`](../docs/01-technical-specification.md) §2.
- Local dev DB: **SQLite** (`database/database.sqlite`, `.env`). Tests: in-memory
  SQLite (`phpunit.xml`). Staging/prod: **PostgreSQL 16**.

## Conventions (enforced in review)

- **Migrations** mirror [`../docs/02-database-schema.md`](../docs/02-database-schema.md)
  exactly (names, types, enum values). Diverge → update the doc in the same commit.
  Write portably: `$table->json()`, `$table->double()`, `$table->enum()` — nothing
  Postgres-only in a migration. PG-specific queries (geohash proximity, `jsonb`
  operators) live behind a repository method, verified by the CI Postgres job.
- **Every mutating endpoint:** Form Request (validation) + Policy (authz) + API
  Resource (response). No raw Eloquent models out of controllers. No business logic in
  controllers — push it to actions/services.
- **Routes** mirror [`../docs/03-api-specification.md`](../docs/03-api-specification.md).
  New endpoint → update the spec in the same commit.
- **Server-side enforcement is the control, not the UI:** the unmatched-messaging
  subscriber gate and the calls subscriber gate (spec §12/§13, security doc §3.4)
  reject at the API layer with `403`. A feature that relies on the app hiding a button
  fails review.
- **Geolocation:** never serialize raw `latitude`/`longitude` into a Resource another
  user can fetch. Distance is bucketed (security doc §4).

## Commands

```powershell
composer install
php artisan migrate            # local SQLite
php artisan test               # in-memory SQLite — must pass before a task is "done"
vendor/bin/pint                # fix style;  vendor/bin/pint --test  to check
composer audit                 # dependency advisories — must be clean
php artisan reverb:start       # only when working on chat/real-time
```

## Not installed here

- `pcov`/`xdebug` (no coverage locally — CI handles it), Redis extension (local dev
  uses the `database` cache/queue/session drivers; prod uses Redis via `predis`).
