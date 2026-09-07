import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Single typed entry point to the backend. Every feature's `data/` layer goes
/// through this — no feature creates its own [Dio]. Endpoints must mirror
/// `docs/03-api-specification.md`; adding a call the spec doesn't have means
/// updating the spec in the same commit (see `CLAUDE.md`).
class ApiClient {
  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.current.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/json'},
            ),
          );

  final Dio _dio;

  Dio get raw => _dio;

  // Auth token wiring (interceptor) lands with the authentication feature in
  // Phase 1 — kept out of Phase 0 scaffolding on purpose.
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
