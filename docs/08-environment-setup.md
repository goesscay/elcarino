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
`build/app/outputs/flutter-apk/app-debug.apk` (`com.mgs.elcarino`, compileSdk 36).
The first build takes ~15 min: Gradle 9.3.1 unpacks, the Android Gradle Plugin +
Kotlin + `android-ndk-r28c` download (Gradle pulls the NDK automatically — no manual
install needed), then compile + dex. Subsequent builds are minutes or less with the
Gradle daemon and caches warm.

**To run the app on Android** you need either a physical device with USB debugging, or
an emulator (`sdkmanager "emulator" "system-images;android-36;google_apis;x86_64"` then
`avdmanager create avd ...` — ~2 GB, needs hardware acceleration). `flutter build apk`
working is sufficient proof the toolchain is correct.

**Onboarding feature's new plugins** (`image_picker`, `permission_handler`,
`flutter_secure_storage`, added in Phase 1 item 2) pulled in Android SDK Platform 34
and 35 plus CMake 3.22.1 as extra Gradle-managed dependencies — `flutter build apk`
auto-installed and licensed them the first time, no manual intervention needed on this
machine. If `sdkmanager`'s own download of those stalls the way the initial SDK install
did, the same curl workaround above applies.

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

Real-time (chat) uses Laravel Reverb (Phase 1 item 8; installed via `composer require
laravel/reverb` + `php artisan install:broadcasting --reverb`, which publishes
`config/broadcasting.php` and `routes/channels.php`). Unlike the other `.env`
credentials, `REVERB_APP_ID`/`REVERB_APP_KEY`/`REVERB_APP_SECRET` aren't third-party
API keys — Reverb is self-hosted, so these are arbitrary strings *you* choose; they
just need to match between the server and whatever's connecting to it. Set
`BROADCAST_CONNECTION=reverb` and fill in all three with any values to actually
exercise broadcasting locally (the default `log` driver just logs events instead of
sending them — fine for confirming an event fires, useless for testing real-time
delivery). Run Reverb alongside `serve` when working on chat:

```powershell
php artisan reverb:start
```

Verified end-to-end on this machine: `reverb:start` boots and stays up, and a real
`broadcast(new NewMessageBroadcast(...))` call against it from `tinker` completes with
no connection/auth error — the full publish round-trip (HMAC-signed HTTP call from
Laravel to Reverb) works, not just "the event class fires" per the automated
`Event::fake()` tests.

Push notifications (Phase 1 item 9) default to `PUSH_PROVIDER=log` — writes each
notification to the log instead of calling Firebase, same role as `SMS_PROVIDER=log`
for OTP. To exercise a real send: create a Firebase project, Project settings ->
Service accounts -> Generate new private key, and fill in `FCM_PROJECT_ID` +
`FCM_SERVICE_ACCOUNT_EMAIL` (the JSON's `client_email`) + `FCM_SERVICE_ACCOUNT_PRIVATE_KEY`
(the JSON's `private_key`, keeping its literal `\n` escapes) plus `PUSH_PROVIDER=fcm`.
**Not verified against a real Firebase project on this machine** — no project
configured here — unlike Reverb above; treat `FcmPushSender` the same as
`TwilioSmsSender`, a real implementation that still needs its first live check before
production.

### Admin panel (Filament, Phase 1 item 11)

`/admin` — session auth with mandatory TOTP, not the mobile Sanctum flow
(docs/06 §3.3). Admin/moderator accounts are provisioned, never self-service (no
registration form). To create the first one locally:

```powershell
cd C:\DatingApp\backend
php artisan tinker
```

```php
$user = \App\Models\User::factory()->create([
    'email' => 'you@example.com',
    'password' => \Illuminate\Support\Facades\Hash::make('a-real-password'),
    'role' => \App\Enums\UserRole::Admin, // or ::Moderator
]);
```

Logging in for the first time redirects straight into TOTP setup (scan the QR with
any authenticator app) before the panel becomes usable at all — there's no way to
opt out of 2FA once a role is `admin`/`moderator`.

### Profile verification (Phase 4)

Selfie verification runs with **no provider account**: `VERIFICATION_PROVIDER=none` (the
default in `.env.example`) never approves or rejects anything itself, so every request lands
in `/admin` → **Verification** for a person to approve or reject. To drive the whole flow on a
laptop, set `VERIFICATION_PROVIDER=fake` in `.env` and choose what it reports with
`VERIFICATION_FAKE_OUTCOME` (`matched` | `not_matched` | `no_face` | `inconclusive`;
`matched` uses `VERIFICATION_FAKE_SCORE`). **The `fake` driver only boots when `APP_ENV` is
`local` or `testing`** — anywhere else the container refuses to build it, so a stray env var
can't hand out verified badges. `.env.example` documents the other knobs
(`VERIFICATION_APPROVE_THRESHOLD`, `VERIFICATION_MAX_ATTEMPTS_PER_DAY`, …).

Selfies are written **encrypted** to the private disk under `verification/` and deleted as soon
as a request is decided, so that folder is normally empty. Restart `php artisan serve` after
changing these `.env` values — the dev server reads them at boot.

**Selfie capture on the Android emulator:** the front-camera pick opens the emulator's virtual
camera scene; press the shutter and the tick. It needs no host webcam.

### Backend tests

```powershell
cd C:\DatingApp\backend
php artisan test
```

Tests run against an in-memory SQLite database (configured in `phpunit.xml`) — fast,
no setup. They also run against **fake storage disks** (`Tests\TestCase::setUp` fakes
`local` and `public` for every test), so the suite can never touch your real
`storage/app/private` — the folder the dev server serves profile photos, voice notes and
chat media from. (Until this was fixed, two test classes deleted `photos/`, `voice-notes/`
and `chat-photos/` there on every run, wiping seeded dev media.) A test that needs to
write a file just writes it; `tests/Feature/TestIsolationTest.php` fails if the isolation
is ever removed. The CI `test-postgres` job re-runs the same suite against PostgreSQL 16 to
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

Each file also carries `REVERB_HOST`/`REVERB_PORT`/`REVERB_APP_KEY`/`REVERB_USE_TLS`
(Phase 1 item 8, chat) — same self-hosted-arbitrary-value framing as the backend's
`REVERB_*` `.env` keys above, not a third-party secret. `config/dev.json` uses
`10.0.2.2`/`8080`/`local-dev-key`/`false`, matching this machine's backend `.env`
exactly — both sides of a local Reverb connection have to agree on the app key or the
WebSocket handshake is rejected. `config/staging.json` / `config/prod.json`'s Reverb
values are still placeholders (`REPLACE_WITH_{STAGING,PROD}_REVERB_APP_KEY`) alongside
their already-placeholder `.example` API URLs — real staging/prod Reverb hosting
(a domain, a load balancer path, a real app key) isn't provisioned yet, same gap as
the API URLs themselves.

Push notifications (Phase 1 item 9) read `FIREBASE_API_KEY`/`FIREBASE_APP_ID`/
`FIREBASE_MESSAGING_SENDER_ID`/`FIREBASE_PROJECT_ID` — all **absent** from every
`config/*.json` on purpose, since no Firebase project exists on this machine
(mirrors the backend's `FCM_*` `.env` keys — see above). `AppConfig
.isFirebaseConfigured` is false with them unset, and every FCM call in
`lib/notifications/` no-ops rather than throwing (same "denial is fine, app
continues" tolerance docs/07 §3.1 already applies to the OS permission prompt
itself). To exercise a real send end-to-end: create a Firebase project (the same
one as the backend's service account, Project settings -> General -> Your apps ->
Add app -> Android, using this app's applicationId `com.mgs.elcarino`), copy its Web
API key/App id/Sender id/Project id into `config/dev.json`, and rebuild. Deliberately
*not* wired via `google-services.json` + the `com.google.gms.google-services` Gradle
plugin — that plugin fails the Gradle build outright without the file present, which
would block `flutter build apk` for every contributor until a real project exists.
`FirebaseOptions` built from these dart-defines gets the app the same result without
that hard requirement.

**Not verified against a real Firebase project on this machine** — none configured
here. `flutter build apk --debug` was confirmed to still succeed with
`firebase_core`/`firebase_messaging` added and no project configured, which was the
actual risk (the Gradle plugin's json requirement, avoided as above) — the
token-registration/receive path itself needs a real project to check.

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
- **Signed media URLs (profile photos) fail to load on the Android emulator
  specifically** — same root cause as the gotcha above, one level deeper: the JSON
  request succeeds (that goes through `config/dev.json`'s `10.0.2.2` base URL), but the
  *signed URL inside the response* is built server-side from `.env`'s `APP_URL`, which
  is `http://localhost:8000` — correct for a desktop browser hitting Filament,
  unreachable from the emulator's own network namespace. Confirmed live while building
  Phase 3 item 1 (voice notes) — `curl` from the host downloaded the file cleanly, only
  the emulator's in-app fetch couldn't resolve the host. Not applicable to any
  `message_attachments`-backed feature any more (chat voice notes, and — confirmed
  live building Phase 3 item 3 — chat photos too: both get their own signed route on
  the `local` disk, generated relative to the current request rather than `APP_URL` —
  see `MessageAttachmentStreamController`), but still true for profile photos
  (`ProfilePhotoResource`, unchanged). No fix applied there — swapping `APP_URL` to
  `10.0.2.2` would break the desktop-browser Filament case instead. Workaround for a
  local emulator session that needs to see a real profile photo: temporarily set
  `APP_URL` to `http://10.0.2.2:8000` in `.env`, restart `php artisan serve`, revert
  after.
- **A native-Android-networking plugin (audio/video players, some image libraries)
  can't reach the dev backend even though every other network call works fine** —
  Dart's own `dart:io` HTTP client (what Dio/the JSON API calls use) doesn't consult
  Android's Network Security Config at all, but a plugin backed by native Android
  networking (`audioplayers`' underlying `MediaPlayer`, confirmed live building Phase 3
  item 1's voice-note playback) does, and by default cleartext (`http://`, not
  `https://`) is blocked outright for `targetSdkVersion >= 28` — silently, no exception
  thrown, `adb logcat` just shows the native component erroring
  (`NuCachedSource2: source returned error -1`) and the backend's own access log shows
  the request never arrived at all. Fixed for debug builds via
  `mobile/android/app/src/debug/res/xml/network_security_config.xml` (permits cleartext
  to `10.0.2.2`/`localhost`/`127.0.0.1` only, referenced from
  `android/app/src/debug/AndroidManifest.xml` — never merged into a release build). A
  newly-added native-networking plugin hitting the same wall needs no new fix, just
  confirmation its target host is one of the three already permitted there.
- **`php artisan migrate` fails on a fresh clone** → you skipped
  `New-Item database\database.sqlite` — Laravel won't create the SQLite file itself.
- **CRLF/LF churn in diffs** → `.gitattributes` normalizes to LF; if you cloned before
  it existed, run `git add --renormalize .` once.
