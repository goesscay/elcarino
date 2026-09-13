import 'dart:convert';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/safety/data/safety_repository.dart';
import 'package:datingapp/safety/domain/report_category.dart';
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

(SafetyRepository, _FakeAdapter) _repositoryReturning(
  Map<String, Map<String, dynamic>> responses,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  final adapter = _FakeAdapter(responses);
  dio.httpClientAdapter = adapter;
  return (
    SafetyRepository(ApiClient(tokenStorage: FakeTokenStorage(), dio: dio)),
    adapter,
  );
}

void main() {
  group('SafetyRepository (docs/03 Safety)', () {
    test(
      'getBlockedUsers maps every entry, null-safe fields included',
      () async {
        final (repository, _) = _repositoryReturning({
          '/safety/blocks': {
            'blocked_users': [
              {
                'id': 1,
                'display_name': 'Jane',
                'photo': {
                  'id': 5,
                  'url': 'https://example.com/photo.jpg',
                  'sort_order': 0,
                  'moderation_status': 'approved',
                },
              },
              {'id': 2, 'display_name': null, 'photo': null},
            ],
          },
        });

        final blockedUsers = await repository.getBlockedUsers();

        expect(blockedUsers, hasLength(2));
        expect(blockedUsers[0].displayName, 'Jane');
        expect(blockedUsers[0].photo!.url, 'https://example.com/photo.jpg');
        expect(blockedUsers[1].displayName, isNull);
        expect(blockedUsers[1].photo, isNull);
      },
    );

    test('block posts the user_id', () async {
      final (repository, adapter) = _repositoryReturning({});

      await repository.block(7);

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/safety/block');
      expect(adapter.lastRequest!.data, {'user_id': 7});
    });

    test('unblock calls DELETE on the right path', () async {
      final (repository, adapter) = _repositoryReturning({});

      await repository.unblock(7);

      expect(adapter.lastRequest!.method, 'DELETE');
      expect(adapter.lastRequest!.path, '/safety/block/7');
    });

    test(
      'report posts category and description, omits an empty description',
      () async {
        final (repository, adapter) = _repositoryReturning({});

        await repository.report(userId: 9, category: ReportCategory.spam);

        expect(adapter.lastRequest!.data, {
          'user_id': 9,
          'category': 'spam',
          'also_block': false,
        });
      },
    );

    test('report includes description and also_block when set', () async {
      final (repository, adapter) = _repositoryReturning({});

      await repository.report(
        userId: 9,
        category: ReportCategory.harassment,
        description: 'Kept messaging after I said no.',
        alsoBlock: true,
      );

      expect(adapter.lastRequest!.data, {
        'user_id': 9,
        'category': 'harassment',
        'description': 'Kept messaging after I said no.',
        'also_block': true,
      });
    });
  });
}
