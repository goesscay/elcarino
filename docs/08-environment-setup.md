# Local Environment Setup

How to run the backend, the mobile app, and their test suites on a dev machine.
Windows-first (that's the current dev box); the commands translate directly to
macOS/Linux.

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| PHP | 8.3+ | needs `pdo_sqlite` + `sqlite3` (local dev), `pdo_pgsql` (staging/prod + CI), `mbstring`, `openssl`, `gd`. On the winget PHP build these are shipped but commented — enable `extension=pdo_sqlite` and `extension=sqlite3` in `php.ini` (done on this machine). |
| Composer | 2.x | works from PowerShell; not on the Git-Bash PATH |
| Flutter | stable (3.47.2) | SDK at `C:\Users\user\flutter`; `C:\Users\user\flutter\bin` on the user PATH |
| JDK | Temurin 17 | portable extract at `C:\Users\user\jdk-17`, `JAVA_HOME` set. Needed for Gradle / the Android build. (The winget MSI install stalled on UAC elevation — the portable zip is the working path here.) |
| Android SDK | cmdline-tools install | at `C:\Users\user\Android\Sdk`, `ANDROID_HOME` / `ANDROID_SDK_ROOT` set. Packages: `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`, `cmdline-tools;latest`. **No emulator/system-image yet** — a physical device or a later `sdkmanager "emulator" "system-images;android-36;google_apis;x86_64"` is needed to run an AVD. |
| Node | 20+ | only for tooling scripts / Reverb's front-end asset build / Filament asset compile |
| PostgreSQL | 16 | **not required locally** — used in staging/prod and the CI parity job. Install only if you want to test PG-specific behaviour locally. |
| Docker | — | optional; not currently used |

### Android SDK notes (this machine)

`sdkmanager` downloads from `dl.google.com` **stall** on this network for larger files
(the Java HTTP client hangs with no timeout). The packages were installed by downloading
the archive ZIPs directly with `curl --speed-limit 2000 --speed-time 20 -C -` (stall-
detect + resume) and laying them out under `C:\Users\user\Android\Sdk\`:
`platform-tools/`, `build-tools/36.0.0/`, `platforms/android-36/`. If you need more
packages and `sdkmanager` hangs, use the same curl approach against the URLs in
`https://dl.google.com/android/repository/repository2-3.xml`.

`flutter doctor` reports the Android toolchain as OK (SDK 36.0.0, licenses accepted).
The only remaining `flutter doctor` `[X]` is Visual Studio (Windows *desktop* apps) —
irrelevant for a mobile app.

**Verified:** `flutter build apk --debug` succeeds end to end — produces
`build/app/outputs/flutter-apk/app-debug.apk` (`com.mgs.datingapp`, compileSdk 36).
The first build takes ~15 min: Gradle 9.3.1 unpacks, the Android Gradle Plugin +
Kotlin + `android-ndk-r28c` download (Gradle pulls the NDK automatically — no manual
install needed), then compile + dex. Subsequent builds are minutes or less with the
Gradle daemon and caches warm.

**To run the app on Android** you need either a physical device with USB debugging, or
an emulator (`sdkmanager "emulator" "system-images;android-36;google_apis;x86_64"` then
`avdmanager create avd ...` — ~2 GB, needs hardware acceleration). `flutter build apk`
working is sufficient proof the toolchain is correct.

**Quick visual preview (web).** The `web` platform is enabled purely for fast previews
during development — the product ships iOS/Android only. To eyeball the current UI
without a device:

```powershell
cd C:\DatingApp\mobile
flutter run -d chrome --dart-define-from-file=config/dev.json
# or, static build served locally:
flutter build web --dart-define-from-file=config/dev.json
python -m http.server 5555 --directory build\web
```

(Web's `API_BASE_URL` should be `http://localhost:8000`, not the Android-emulator
`10.0.2.2` — add a `config/web.json` when web previews start hitting the real API.)

## Backend (`/backend` — Laravel 13)

```powershell
cd C:\DatingApp\backend
composer install
Copy-Item .env.example .env
php artisan key:generate
New-Item -ItemType File database\database.sqlite -Force   # local dev DB
php artisan migrate
php artisan serve                                          # http://127.0.0.1:8000
```

Real-time (chat) uses Laravel Reverb — run it alongside `serve` when working on chat:

```powershell
php artisan reverb:start
```

### Backend tests

```powershell
cd C:\DatingApp\backend
php artisan test
```

Tests run against an in-memory SQLite database (configured in `phpunit.xml`) — fast,
no setup. The CI `test-postgres` job re-runs the same suite against PostgreSQL 16 to
catch engine differences before they reach staging.

### Environment matrix (backend)

| Env | DB | Set via |
|---|---|---|
| local | SQLite file (`database/database.sqlite`) | `.env` |
| testing | SQLite `:memory:` | `phpunit.xml` |
| staging / production | PostgreSQL 16 | platform secrets, never `.env` in the repo |

`.env.example` is the source of truth for which keys exist — every new integration adds
its key there (with an empty/placeholder value), same commit.

## Mobile (`/mobile` — Flutter, Riverpod)

```powershell
# one-time: add Flutter to PATH
$env:Path += ";C:\Users\user\flutter\bin"

cd C:\DatingApp\mobile
flutter pub get
flutter run --dart-define-from-file=config/dev.json
```

### Flavors / environments (mobile)

Starting approach: build-time config via `--dart-define-from-file`, read into a single
`AppConfig` in `lib/core/config/`. Files:

| File | `API_BASE_URL` | Use |
|---|---|---|
| `config/dev.json` | `http://10.0.2.2:8000/api/v1` (Android emulator → host) | local dev |
| `config/staging.json` | staging API URL | QA builds |
| `config/prod.json` | production API URL | release |

```powershell
flutter run   --dart-define-from-file=config/dev.json
flutter build apk --dart-define-from-file=config/prod.json
```

Full native flavors (distinct application IDs, icons, and names per environment so
dev/staging/prod can be installed side by side) are a later refinement — add
`flutter_flavorizr` or manual Gradle `productFlavors` + iOS schemes when the need
arises (likely Phase 2, when TestFlight/Play internal testing starts).

### Mobile tests

```powershell
cd C:\DatingApp\mobile
flutter test --dart-define-from-file=config/dev.json
```

`AppConfig` fails loud at startup if `API_BASE_URL` isn't set, so tests need the
`--dart-define-from-file` flag too (CI passes it). `flutter analyze` and
`dart format --output=none --set-exit-if-changed .` must also pass — CI enforces both.

## Secrets

- Backend: `.env` only (git-ignored). Never commit real keys. `.env.example` carries
  key *names* with blank values.
- Mobile: no secrets in `config/*.json` beyond public base URLs. Anything sensitive
  (e.g. a third-party client key that must ship in the binary) is documented as a risk
  and injected at build time via CI secrets + `--dart-define`, never checked in.
- See [`06-security-architecture.md`](06-security-architecture.md) §10.

## Common gotchas

- **`flutter` not found** → the SDK is at `C:\Users\user\flutter`; add `...\bin` to PATH
  (per-session `$env:Path += ";C:\Users\user\flutter\bin"` or permanently via System
  Environment Variables).
- **Android emulator can't reach the API** → use `http://10.0.2.2:8000`, not
  `localhost`, from inside the emulator (`10.0.2.2` is the emulator's alias for the
  host). iOS simulator can use `localhost`.
- **`php artisan migrate` fails on a fresh clone** → you skipped
  `New-Item database\database.sqlite` — Laravel won't create the SQLite file itself.
- **CRLF/LF churn in diffs** → `.gitattributes` normalizes to LF; if you cloned before
  it existed, run `git add --renormalize .` once.
