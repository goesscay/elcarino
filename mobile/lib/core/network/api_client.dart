import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';
import '../config/app_config.dart';
import 'api_exception.dart';

/// Single typed entry point to the backend. Every feature's `data/` layer goes
/// through this — no feature creates its own [Dio]. Endpoints must mirror
/// `docs/03-api-specification.md`; adding a call the spec doesn't have means
/// updating the spec in the same commit (see `CLAUDE.md`).
class ApiClient {
  ApiClient({required this._tokenStorage, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.current.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Accept': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Escape hatch for calls that need raw dio features (e.g. [FormData] photo
  /// uploads) that don't fit the [request] wrapper's shape.
  Dio get raw => _dio;

  /// Runs one call through the shared error translation below, so
  /// repositories/screens only ever deal with [ApiException] /
  /// [ValidationException] — never a raw [DioException] or `response.data`.
  Future<Response<dynamic>> request(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.request(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method),
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  Exception _translate(DioException e) {
    final response = e.response;
    if (response == null) {
      return ApiException(
        code: 'network_error',
        message: 'Could not reach the server. Check your connection and try again.',
        statusCode: 0,
      );
    }

    final body = response.data;

    if (response.statusCode == 422 && body is Map && body['errors'] is Map) {
      final rawErrors = (body['errors'] as Map).cast<String, dynamic>();
      return ValidationException(
        rawErrors.map((key, value) => MapEntry(key, List<String>.from(value as List))),
      );
    }

    if (body is Map && body['error'] is Map) {
      final error = (body['error'] as Map).cast<String, dynamic>();
      return ApiException(
        code: error['code'] as String? ?? 'unknown_error',
        message: error['message'] as String? ?? 'Something went wrong. Please try again.',
        statusCode: response.statusCode ?? 500,
      );
    }

    return ApiException(
      code: 'unknown_error',
      message: 'Something went wrong. Please try again.',
      statusCode: response.statusCode ?? 500,
    );
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokenStorage: ref.watch(tokenStorageProvider)),
);
