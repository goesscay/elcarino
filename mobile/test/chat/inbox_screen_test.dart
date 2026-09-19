import 'package:datingapp/chat/data/chat_repository.dart';
import 'package:datingapp/chat/domain/conversation.dart';
import 'package:datingapp/chat/presentation/inbox_screen.dart';
import 'package:datingapp/core/network/api_exception.dart';
import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/matching/domain/match.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository(this._load);

  final Future<List<Conversation>> Function() _load;
  int calls = 0;

  @override
  Future<List<Conversation>> getConversations() {
    calls++;
    return _load();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Conversation _conversation({
  required int id,
  required String name,
  DateTime? lastMessageAt,
  String? preview,
  int unread = 0,
  int? matchId = 1,
}) => Conversation(
  id: id,
  matchId: matchId,
  otherUser: MatchedUser(
    id: id + 100,
    displayName: name,
    age: 28,
    bio: null,
    isVerified: false,
    photos: const [], // no network in tests — placeholders render
  ),
  lastMessageAt: lastMessageAt,
  lastMessagePreview: preview,
  unreadCount: unread,
  requiresSubscriptionToMessage: false,
);

Widget _host(_FakeChatRepository repo) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const InboxScreen()),
      GoRoute(
        path: '/discover',
        builder: (context, state) => const Scaffold(body: Text('discover')),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) =>
            Scaffold(body: Text('chat ${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
}

void main() {
  group('InboxScreen', () {
    testWidgets('shows the new-matches row and started conversations', (
      tester,
    ) async {
      final repo = _FakeChatRepository(
        () async => [
          _conversation(id: 1, name: 'Nia'), // new match: no messages yet
          _conversation(
            id: 2,
            name: 'Sonia',
            lastMessageAt: DateTime.now(),
            preview: 'That sounds fun',
            unread: 3,
          ),
        ],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('New matches'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Nia'), findsOneWidget);
      expect(find.text('Sonia'), findsOneWidget);
      expect(find.text('That sounds fun'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // unread badge
    });

    testWidgets('caps a large unread count at 99+', (tester) async {
      final repo = _FakeChatRepository(
        () async => [
          _conversation(
            id: 2,
            name: 'Sonia',
            lastMessageAt: DateTime.now(),
            preview: 'hi',
            unread: 240,
          ),
        ],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('an empty inbox shows guidance that leads back to Discover', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_FakeChatRepository(() async => [])));
      await tester.pumpAndSettle();

      expect(find.text('No matches yet'), findsOneWidget);
      await tester.tap(find.text('Keep discovering'));
      await tester.pumpAndSettle();
      expect(find.text('discover'), findsOneWidget);
    });

    testWidgets('an error shows the message and Retry reloads', (tester) async {
      var attempt = 0;
      final repo = _FakeChatRepository(() async {
        attempt++;
        if (attempt == 1) {
          throw ApiException(
            code: 'server_error',
            message: 'Server unavailable',
            statusCode: 500,
          );
        }
        return [_conversation(id: 1, name: 'Nia')];
      });
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(find.text('Server unavailable'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Nia'), findsOneWidget);
      expect(repo.calls, 2);
    });

    testWidgets('tapping a conversation opens it', (tester) async {
      final repo = _FakeChatRepository(
        () async => [
          _conversation(
            id: 2,
            name: 'Sonia',
            lastMessageAt: DateTime.now(),
            preview: 'hi',
          ),
        ],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sonia'));
      await tester.pumpAndSettle();

      expect(find.text('chat 2'), findsOneWidget);
    });

    testWidgets('long-press offers Unmatch for a matched conversation', (
      tester,
    ) async {
      final repo = _FakeChatRepository(
        () async => [
          _conversation(
            id: 2,
            name: 'Sonia',
            lastMessageAt: DateTime.now(),
            preview: 'hi',
          ),
        ],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Sonia'));
      await tester.pumpAndSettle();

      expect(find.text('Unmatch Sonia'), findsOneWidget);
    });
  });

  group('formatChatTimestamp', () {
    final now = DateTime(2026, 9, 19, 15, 30); // a Saturday

    test('today shows the time', () {
      expect(
        formatChatTimestamp(DateTime(2026, 9, 19, 9, 5), now: now),
        '09:05',
      );
    });

    test('yesterday shows "Yesterday"', () {
      expect(
        formatChatTimestamp(DateTime(2026, 9, 18, 23, 59), now: now),
        'Yesterday',
      );
    });

    test('within the past week shows the weekday', () {
      expect(formatChatTimestamp(DateTime(2026, 9, 15, 12), now: now), 'Tue');
    });

    test('older than a week shows month/day', () {
      expect(formatChatTimestamp(DateTime(2026, 9, 1, 12), now: now), '9/1');
    });
  });
}
