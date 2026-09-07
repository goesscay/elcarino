/// Build-time configuration, injected via `--dart-define-from-file=config/<env>.json`.
///
/// See `docs/08-environment-setup.md`. Never put secrets here — only public values
/// like the API base URL. Anything sensitive is injected via CI `--dart-define`.
library;

enum AppEnvironment { dev, staging, prod }

class AppConfig {
  const AppConfig._({required this.environment, required this.apiBaseUrl});

  final AppEnvironment environment;
  final String apiBaseUrl;

  bool get isProd => environment == AppEnvironment.prod;

  static const _rawEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const _rawApiBaseUrl = String.fromEnvironment('API_BASE_URL');

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
    return AppConfig._(
      environment: AppEnvironment.values.firstWhere(
        (e) => e.name == _rawEnv,
        orElse: () => AppEnvironment.dev,
      ),
      apiBaseUrl: _rawApiBaseUrl,
    );
  }
}
