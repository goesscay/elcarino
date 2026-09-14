import 'dart:convert';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/discovery/data/discovery_repository.dart';
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

(DiscoveryRepository, _FakeAdapter) _repositoryReturning(
  Map<String, Map<String, dynamic>> responses,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  final adapter = _FakeAdapter(responses);
  dio.httpClientAdapter = adapter;
  return (
    DiscoveryRepository(ApiClient(tokenStorage: FakeTokenStorage(), dio: dio)),
    adapter,
  );
}

void main() {
  group('DiscoveryRepository (docs/03 Discovery + Users location)', () {
    test('updateLocation truncates to 3 decimal places client-side', () async {
      final (repository, adapter) = _repositoryReturning({});

      await repository.updateLocation(
        latitude: 3.1390123,
        longitude: 101.6870456,
      );

      expect(adapter.lastRequest!.path, '/users/me/location');
      expect(adapter.lastRequest!.data, {
        'latitude': 3.139,
        'longitude': 101.687,
      });
    });

    test('getFeed maps candidates and meta', () async {
      final (repository, _) = _repositoryReturning({
        '/discovery/feed': {
          'candidates': [
            {
              'id': 1,
              'display_name': 'Jane',
              'age': 28,
              'bio': 'Hi',
              'relationship_goal': null,
              'is_verified': false,
              'distance_km': 0,
              'shared_interests_count': 2,
              'shared_interests': ['Hiking', 'Coffee'],
              'photos': [],
              'prompts': [],
            },
          ],
          'meta': {'page': 1, 'per_page': 20, 'has_more': true},
        },
      });

      final page = await repository.getFeed();

      expect(page.candidates, hasLength(1));
      expect(page.candidates.single.displayName, 'Jane');
      expect(page.candidates.single.distanceLabel, 'less than 1 km away');
      expect(page.candidates.single.sharedInterests, ['Hiking', 'Coffee']);
      expect(page.hasMore, isTrue);
    });
  });

  group('DiscoveryRepository boost (Phase 2 item 3)', () {
    test('getBoostStatus maps an active boost', () async {
      final (repository, _) = _repositoryReturning({
        '/discovery/boost': {
          'active': true,
          'ends_at': '2026-01-01T12:30:00Z',
          'used_this_month': 1,
          'limit': 1,
        },
      });

      final status = await repository.getBoostStatus();

      expect(status.active, isTrue);
      expect(status.endsAt, DateTime.parse('2026-01-01T12:30:00Z'));
      expect(status.limit, 1);
      expect(status.canActivateAnother, isFalse);
    });

    test('getBoostStatus maps a non-subscriber (limit: false)', () async {
      final (repository, _) = _repositoryReturning({
        '/discovery/boost': {
          'active': false,
          'ends_at': null,
          'used_this_month': 0,
          'limit': false,
        },
      });

      final status = await repository.getBoostStatus();

      expect(status.isEntitled, isFalse);
      expect(status.limit, isNull);
      expect(status.canActivateAnother, isFalse);
    });

    test('activateBoost posts to /discovery/boost', () async {
      final (repository, adapter) = _repositoryReturning({});

      await repository.activateBoost();

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/discovery/boost');
    });
  });
}
