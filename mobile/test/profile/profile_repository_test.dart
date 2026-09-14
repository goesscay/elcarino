import 'dart:convert';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/profile/data/profile_repository.dart';
import 'package:datingapp/profile/domain/gender.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_token_storage.dart';

/// Returns a canned response keyed by request path — enough to exercise
/// ProfileRepository's JSON mapping without a real backend.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, Map<String, dynamic>> responses;
  final List<String> calls = [];
  dynamic lastData;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    lastData = options.data;
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

(ProfileRepository, _FakeAdapter) _repositoryReturning(
  Map<String, Map<String, dynamic>> responses,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  final adapter = _FakeAdapter(responses);
  dio.httpClientAdapter = adapter;
  return (
    ProfileRepository(ApiClient(tokenStorage: FakeTokenStorage(), dio: dio)),
    adapter,
  );
}

void main() {
  group('ProfileRepository interests (docs/03 Interests group)', () {
    test('getInterestCatalogue maps every entry', () async {
      final (repository, _) = _repositoryReturning({
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

    test(
      'updateInterests posts to /interests/me and returns the new set',
      () async {
        final (repository, _) = _repositoryReturning({
          '/interests/me': {
            'interests': [
              {'id': 1, 'name': 'Hiking', 'category': 'Sports'},
            ],
          },
        });

        final result = await repository.updateInterests([1]);

        expect(result, hasLength(1));
        expect(result.single.id, 1);
      },
    );
  });

  group('ProfileRepository prompts reorder (docs/04 item 4)', () {
    test('deletePromptAnswer calls DELETE on the right path', () async {
      final (repository, adapter) = _repositoryReturning({});

      await repository.deletePromptAnswer(7);

      expect(adapter.calls, contains('DELETE /prompts/me/7'));
    });

    test(
      'updatePrompts resubmits in the given order (how reorder persists)',
      () async {
        final (repository, adapter) = _repositoryReturning({
          '/prompts/me': {
            'prompts': [
              {'prompt_id': 2, 'prompt': 'B', 'answer': 'y'},
              {'prompt_id': 1, 'prompt': 'A', 'answer': 'x'},
            ],
          },
        });

        final result = await repository.updatePrompts([(2, 'y'), (1, 'x')]);

        expect(adapter.calls, contains('PUT /prompts/me'));
        expect(result.map((p) => p.promptId), [2, 1]);
      },
    );
  });

  group('ProfileRepository basics (Phase 2 item 2)', () {
    test(
      'updateProfileBasics includes religion and politics when set',
      () async {
        final (repository, adapter) = _repositoryReturning({
          '/profiles/me': {
            'profile': {
              'id': 1,
              'display_name': 'Jane',
              'birth_date': '1995-06-15',
              'gender': 'woman',
              'bio': null,
              'relationship_goal': null,
              'religion': 'buddhist',
              'politics': 'centrist',
              'is_verified': false,
              'completion_pct': 40,
            },
          },
        });

        await repository.updateProfileBasics(
          displayName: 'Jane',
          birthDate: DateTime(1995, 6, 15),
          gender: Gender.woman,
          religion: 'buddhist',
          politics: 'centrist',
        );

        expect(adapter.calls, contains('PUT /profiles/me'));
        expect(adapter.lastData['religion'], 'buddhist');
        expect(adapter.lastData['politics'], 'centrist');
      },
    );

    test('updateProfileBasics omits religion and politics when null', () async {
      final (repository, adapter) = _repositoryReturning({
        '/profiles/me': {
          'profile': {
            'id': 1,
            'display_name': 'Jane',
            'birth_date': '1995-06-15',
            'gender': 'woman',
            'bio': null,
            'relationship_goal': null,
            'is_verified': false,
            'completion_pct': 40,
          },
        },
      });

      await repository.updateProfileBasics(
        displayName: 'Jane',
        birthDate: DateTime(1995, 6, 15),
        gender: Gender.woman,
      );

      expect(adapter.lastData.containsKey('religion'), isFalse);
      expect(adapter.lastData.containsKey('politics'), isFalse);
    });
  });
}
