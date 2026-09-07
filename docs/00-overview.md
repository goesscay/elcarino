# DatingApp — Development Documentation

> **Naming note:** "DatingApp" / `com.mgs.datingapp` is a placeholder used throughout this
> documentation and codebase until branding (open decision #2, see
> [`05-open-decisions.md`](05-open-decisions.md)) is finalized. When the real name lands,
> rename via a single find-and-replace pass across `/docs`, `/mobile`, and `/backend`
> before Phase 1 sign-off — don't let the placeholder leak into production config, app
> store listings, or package identifiers.

This folder is the internal, engineering-facing counterpart to the client-facing
proposal in [`/proposal`](../proposal). The proposal sells the vision; these documents
drive the actual build. Read them in order:

| # | Document | Purpose |
|---|----------|---------|
| 1 | [`01-technical-specification.md`](01-technical-specification.md) | Product scope, tech stack, architecture, module-by-module feature spec |
| 2 | [`02-database-schema.md`](02-database-schema.md) | Full table definitions (columns, types, keys, indexes) |
| 3 | [`03-api-specification.md`](03-api-specification.md) | REST endpoint catalogue with request/response shapes |
| 4 | [`04-development-phases.md`](04-development-phases.md) | Phase 0–5 task breakdown, testing gates, timeline |
| 5 | [`05-open-decisions.md`](05-open-decisions.md) | The 30 client decisions — tracked with current working assumptions |
| 6 | [`06-security-architecture.md`](06-security-architecture.md) | Threat model, auth/authz, geolocation privacy, data classification, rate limiting, compliance flags |
| 7 | [`07-ui-ux-design.md`](07-ui-ux-design.md) | Screen inventory, navigation map, per-screen wireframe specs, placeholder design system |

The root [`CLAUDE.md`](../CLAUDE.md) tells Claude Code *how* to work in this repo
(phase discipline, coding conventions, commit style). Read this overview for *what*
we're building; read `CLAUDE.md` for *how* to build it.

## Quick facts

| | |
|---|---|
| **Product** | Niche dating app — meaningful connections, verified profiles, smart matching, strong safety tooling |
| **Not** | A visual or functional clone of Tinder/Bumble — distinct branding, UI/UX and a defined niche/community |
| **Launch markets** | Malaysia (launch), then Maldives and India (phased rollout) |
| **Mobile** | Flutter, feature-first + Clean Architecture |
| **Backend** | Laravel 13 / PHP 8.3+, PostgreSQL, Redis, REST API |
| **Status as of this doc** | Pre-development — Phase 0 (Architecture & Design) |

## How scope is expressed in these docs

The original client requirements distinguish **required** features (explicitly stated
by the client) from **proposed** features (recommended by MGS, pending client sign-off).
That distinction is preserved everywhere below via inline tags:

- **[REQUIRED]** — explicit client requirement; build it.
- **[PROPOSED]** — MGS recommendation; build it as part of the phase it's scheduled in
  unless [`05-open-decisions.md`](05-open-decisions.md) says otherwise.
- **[TBD-#]** — depends on one of the 30 open decisions; the number matches the item in
  `05-open-decisions.md`. A working default is stated so development isn't blocked, but
  treat it as provisional — confirm before it hardens into shipped UX, pricing, or legal copy.
