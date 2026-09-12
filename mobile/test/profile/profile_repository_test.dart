import 'dart:convert';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_token_storage.dart';

/// Returns a canned response keyed by request path — enough to exercise
/// ProfileRepository's JSON mapping without a real backend.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, Map<String, dynamic>> responses;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = responses[options.path];
    if (body == null) {
      throw StateError('No fake response configured for ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

ProfileRepository _repositoryReturning(Map<String, Map<String, dynamic>> responses) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = _FakeAdapter(responses);
  return ProfileRepository(ApiClient(tokenStorage: FakeTokenStorage(), dio: dio));
}

void main() {
  group('ProfileRepository interests (docs/03 Interests group)', () {
    test('getInterestCatalogue maps every entry', () async {
      final repository = _repositoryReturning({
        '/interests': {
          'interests': [
            {'id': 1, 'name': 'Hiking', 'category': 'Sports'},
            {'id': 2, 'name': 'Coffee', 'category': null},
          ],
        },
      });

      final result = await repository.getInterestCatalogue();

      expect(result, hasLength(2));
      expect(result[0].name, 'Hiking');
      expect(result[0].category, 'Sports');
      expect(result[1].category, isNull);
    });

    test('updateInterests posts to /interests/me and returns the new set', () async {
      final repository = _repositoryReturning({
        '/interests/me': {
          'interests': [
            {'id': 1, 'name': 'Hiking', 'category': 'Sports'},
          ],
        },
      });

      final result = await repository.updateInterests([1]);

      expect(result, hasLength(1));
      expect(result.single.id, 1);
    });
  });
}
