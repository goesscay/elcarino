# backend/ — Elcarino API (Laravel 13)

REST API for the Elcarino mobile client, plus the Filament admin panel.

- **How to work here:** [`CLAUDE.md`](CLAUDE.md) (Laravel specifics) + the repo root
  [`../CLAUDE.md`](../CLAUDE.md).
- **What to build:** [`../docs/01-technical-specification.md`](../docs/01-technical-specification.md),
  schema in [`../docs/02-database-schema.md`](../docs/02-database-schema.md), endpoints
  in [`../docs/03-api-specification.md`](../docs/03-api-specification.md).
- **Local setup:** [`../docs/08-environment-setup.md`](../docs/08-environment-setup.md).

## Quick start

```powershell
composer install
Copy-Item .env.example .env
php artisan key:generate
New-Item -ItemType File database\database.sqlite -Force
php artisan migrate
php artisan serve
```

Status: Phase 0 scaffold. Feature migrations, models, and endpoints land in Phase 1,
one feature at a time (auth first).
