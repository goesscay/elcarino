import 'dart:convert';

import 'package:datingapp/chat/data/chat_repository.dart';
import 'package:datingapp/core/network/api_client.dart';
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

(ChatRepository, _FakeAdapter) _repositoryReturning(
  Map<String, Map<String, dynamic>> responses,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  final adapter = _FakeAdapter(responses);
  dio.httpClientAdapter = adapter;
  return (
    ChatRepository(ApiClient(tokenStorage: FakeTokenStorage(), dio: dio)),
    adapter,
  );
}

Map<String, dynamic> _otherUserJson() => {
  'id': 9,
  'display_name': 'Jane',
  'age': 28,
  'bio': null,
  'is_verified': true,
  'photos': [],
};

void main() {
  group('ChatRepository (docs/03 Chat)', () {
    test('getConversations maps every conversation', () async {
      final (repository, _) = _repositoryReturning({
        '/chat/conversations': {
          'conversations': [
            {
              'id': 1,
              'match_id': 5,
              'other_user': _otherUserJson(),
              'last_message_at': '2026-09-16T00:00:00.000000Z',
              'last_message_preview': 'hey there',
              'unread_count': 2,
              'requires_subscription_to_message': false,
            },
          ],
        },
      });

      final conversations = await repository.getConversations();

      expect(conversations, hasLength(1));
      expect(conversations.single.otherUser.displayName, 'Jane');
      expect(conversations.single.lastMessagePreview, 'hey there');
      expect(conversations.single.unreadCount, 2);
      expect(conversations.single.hasMessages, isTrue);
    });

    test('getConversations maps a fresh match with no messages yet', () async {
      final (repository, _) = _repositoryReturning({
        '/chat/conversations': {
          'conversations': [
            {
              'id': 2,
              'match_id': 6,
              'other_user': _otherUserJson(),
              'last_message_at': null,
              'last_message_preview': null,
              'unread_count': 0,
              'requires_subscription_to_message': false,
            },
          ],
        },
      });

      final conversations = await repository.getConversations();

      expect(conversations.single.hasMessages, isFalse);
      expect(conversations.single.lastMessageAt, isNull);
    });

    test(
      'getMessages sends the page number and maps the pagination meta',
      () async {
        final (repository, adapter) = _repositoryReturning({
          '/chat/conversations/1/messages': {
            'messages': [
              {
                'id': 10,
                'conversation_id': 1,
                'sender_id': 9,
                'body': 'hi',
                'type': 'text',
                'read_at': null,
                'created_at': '2026-09-16T00:00:00.000000Z',
              },
            ],
            'meta': {'page': 2, 'per_page': 30, 'has_more': true},
          },
        });

        final page = await repository.getMessages(1, page: 2);

        expect(adapter.lastRequest!.queryParameters, {'page': 2});
        expect(page.messages, hasLength(1));
        expect(page.messages.single.body, 'hi');
        expect(page.hasMore, isTrue);
      },
    );

    test('sendMessage posts the body and maps the created message', () async {
      final (repository, adapter) = _repositoryReturning({
        '/chat/conversations/1/messages': {
          'message': {
            'id': 11,
            'conversation_id': 1,
            'sender_id': 3,
            'body': 'Hey there!',
            'type': 'text',
            'read_at': null,
            'created_at': '2026-09-16T00:00:00.000000Z',
          },
        },
      });

      final message = await repository.sendMessage(1, 'Hey there!');

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.data, {'body': 'Hey there!'});
      expect(message.body, 'Hey there!');
      expect(message.isRead, isFalse);
    });

    test('markRead calls PUT on the right path', () async {
      final (repository, adapter) = _repositoryReturning({});

      await repository.markRead(1);

      expect(adapter.lastRequest!.method, 'PUT');
      expect(adapter.lastRequest!.path, '/chat/conversations/1/read');
    });
  });
}
