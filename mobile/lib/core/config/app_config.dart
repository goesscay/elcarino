/// Build-time configuration, injected via `--dart-define-from-file=config/<env>.json`.
///
/// See `docs/08-environment-setup.md`. Never put secrets here — only public values
/// like the API base URL. Anything sensitive is injected via CI `--dart-define`.
library;

enum AppEnvironment { dev, staging, prod }

class AppConfig {
  const AppConfig._({
    required this.environment,
    required this.apiBaseUrl,
    required this.reverbHost,
    required this.reverbPort,
    required this.reverbAppKey,
    required this.reverbUseTls,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;

  /// Laravel Reverb (Phase 1 item 8, chat) connection settings. Unlike a
  /// third-party Pusher cluster, these are arbitrary self-hosted values that
  /// just need to match the server (see `docs/08-environment-setup.md`) —
  /// not secrets, so fine to bake in at build time like [apiBaseUrl].
  final String reverbHost;
  final int reverbPort;
  final String reverbAppKey;
  final bool reverbUseTls;

  bool get isProd => environment == AppEnvironment.prod;

  /// The Sanctum-guarded broadcasting auth endpoint a private/presence
  /// channel subscription is authorized against. Registered outside the
  /// `/api/v1` prefix — see `backend/bootstrap/app.php`'s `withBroadcasting`
  /// call — so this strips [apiBaseUrl]'s trailing `/v1` rather than just
  /// appending to it.
  String get reverbAuthEndpoint {
    final root = apiBaseUrl.endsWith('/v1')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - '/v1'.length)
        : apiBaseUrl;
    return '$root/broadcasting/auth';
  }

  static const _rawEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const _rawApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _rawReverbHost = String.fromEnvironment('REVERB_HOST');
  static const _rawReverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 8080,
  );
  static const _rawReverbAppKey = String.fromEnvironment('REVERB_APP_KEY');
  static const _rawReverbUseTls = bool.fromEnvironment('REVERB_USE_TLS');

  /// Resolved once at startup. Throws early if the config file wasn't passed —
  /// better a loud failure at launch than a silent wrong-endpoint at runtime.
  static final AppConfig current = _resolve();

  static AppConfig _resolve() {
    if (_rawApiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not set. Run with '
        '--dart-define-from-file=config/dev.json (see docs/08-environment-setup.md).',
      );
    }
    if (_rawReverbHost.isEmpty || _rawReverbAppKey.isEmpty) {
      throw StateError(
        'REVERB_HOST / REVERB_APP_KEY are not set. Run with '
        '--dart-define-from-file=config/dev.json (see docs/08-environment-setup.md).',
      );
    }
    return AppConfig._(
      environment: AppEnvironment.values.firstWhere(
        (e) => e.name == _rawEnv,
        orElse: () => AppEnvironment.dev,
      ),
      apiBaseUrl: _rawApiBaseUrl,
      reverbHost: _rawReverbHost,
      reverbPort: _rawReverbPort,
      reverbAppKey: _rawReverbAppKey,
      reverbUseTls: _rawReverbUseTls,
    );
  }
}
