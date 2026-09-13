import 'dart:convert';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/matching/data/matching_repository.dart';
import 'package:datingapp/matching/domain/swipe_direction.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_token_storage.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, Map<String, dynamic>> responses;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final body = responses[options.path] ?? {'message': 'ok'};
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

(MatchingRepository, _FakeAdapter) _repositoryReturning(
  Map<String, Map<String, dynamic>> responses,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  final adapter = _FakeAdapter(responses);
  dio.httpClientAdapter = adapter;
  return (
    MatchingRepository(ApiClient(tokenStorage: FakeTokenStorage(), dio: dio)),
    adapter,
  );
}

void main() {
  group('MatchingRepository (docs/03 Swipes + Matches)', () {
    test('swipe posts target_id and direction, maps a match', () async {
      final (repository, adapter) = _repositoryReturning({
        '/swipes': {'matched': true, 'match_id': 42},
      });

      final result = await repository.swipe(
        targetId: 7,
        direction: SwipeDirection.right,
      );

      expect(adapter.lastRequest!.data, {'target_id': 7, 'direction': 'right'});
      expect(result.matched, isTrue);
      expect(result.matchId, 42);
    });

    test('swipe maps a non-match', () async {
      final (repository, _) = _repositoryReturning({
        '/swipes': {'matched': false, 'match_id': null},
      });

      final result = await repository.swipe(
        targetId: 7,
        direction: SwipeDirection.left,
      );

      expect(result.matched, isFalse);
      expect(result.matchId, isNull);
    });

    test('getMatches maps every match and its other_user', () async {
      final (repository, _) = _repositoryReturning({
        '/matches': {
          'matches': [
            {
              'id': 1,
              'other_user': {
                'id': 9,
                'display_name': 'Jane',
                'age': 28,
                'bio': null,
                'is_verified': true,
                'photos': [],
              },
              'matched_at': '2026-09-16T00:00:00.000000Z',
              'unmatched_at': null,
            },
          ],
        },
      });

      final matches = await repository.getMatches();

      expect(matches, hasLength(1));
      expect(matches.single.otherUser.displayName, 'Jane');
      expect(matches.single.isActive, isTrue);
    });

    test('unmatch calls DELETE on the right path', () async {
      final (repository, adapter) = _repositoryReturning({});

      await repository.unmatch(5);

      expect(adapter.lastRequest!.method, 'DELETE');
      expect(adapter.lastRequest!.path, '/matches/5');
    });
  });
}
