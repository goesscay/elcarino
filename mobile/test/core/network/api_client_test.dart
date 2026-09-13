import 'dart:convert';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_token_storage.dart';

/// Returns a canned response for every request — no real network involved.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic>? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

ApiClient _clientReturning({
  required int statusCode,
  Map<String, dynamic>? body,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = _FakeAdapter(statusCode: statusCode, body: body);
  return ApiClient(tokenStorage: FakeTokenStorage(), dio: dio);
}

void main() {
  group('ApiClient error translation (docs/03 cross-cutting standards)', () {
    test('maps a 422 with an "errors" key to ValidationException', () async {
      final client = _clientReturning(
        statusCode: 422,
        body: {
          'message': 'The given data was invalid.',
          'errors': {
            'email': ['The email field is required.'],
          },
        },
      );

      await expectLater(
        client.request('/auth/register', method: 'POST'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.firstError('email'),
            'email error',
            'The email field is required.',
          ),
        ),
      );
    });

    test('maps a business-rule "error" envelope to ApiException', () async {
      final client = _clientReturning(
        statusCode: 422,
        body: {
          'error': {
            'code': 'invalid_otp',
            'message': 'That code is invalid or has expired.',
          },
        },
      );

      await expectLater(
        client.request('/auth/otp/verify', method: 'POST'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'invalid_otp')
              .having(
                (e) => e.message,
                'message',
                'That code is invalid or has expired.',
              ),
        ),
      );
    });

    test('a 404 with an "error" envelope also maps to ApiException', () async {
      final client = _clientReturning(
        statusCode: 404,
        body: {
          'error': {
            'code': 'profile_not_found',
            'message': 'Profile has not been created yet.',
          },
        },
      );

      await expectLater(
        client.request('/profiles/me', method: 'GET'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'profile_not_found',
          ),
        ),
      );
    });
  });
}
