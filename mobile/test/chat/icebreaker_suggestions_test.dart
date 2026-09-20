import 'dart:async';
import 'dart:convert';

import 'package:datingapp/chat/data/chat_repository.dart';
import 'package:datingapp/chat/domain/icebreakers.dart';
import 'package:datingapp/chat/presentation/icebreaker_suggestions.dart';
import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/core/network/api_exception.dart';
import 'package:datingapp/core/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_token_storage.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responses);

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
    return ResponseBody.fromString(
      jsonEncode(responses[options.path] ?? {}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeChat implements ChatRepository {
  _FakeChat({required this.load, this.refresh});

  Future<IcebreakerSet> Function() load;
  Future<IcebreakerSet> Function()? refresh;
  int loads = 0;
  int refreshes = 0;
  final ids = <int>[];

  @override
  Future<IcebreakerSet> getIcebreakers(int conversationId) {
    loads++;
    ids.add(conversationId);
    return load();
  }

  @override
  Future<IcebreakerSet> refreshIcebreakers(int conversationId) {
    refreshes++;
    return refresh!();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

IcebreakerSet _set(List<String> lines, {String source = 'template'}) =>
    IcebreakerSet(lines: lines, source: source);

ApiException _error(String message, [int status = 500]) =>
    ApiException(code: 'error', message: message, statusCode: status);

/// The widget on its own, with the parent's `onPick` recorded.
Future<List<String>> _pump(WidgetTester tester, _FakeChat chat) async {
  final picked = <String>[];
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(chat)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: IcebreakerSuggestions(
              conversationId: 42,
              onPick: picked.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  group('IcebreakerSet and ChatRepository (docs/03 Chat)', () {
    (ChatRepository, _RecordingAdapter) repoReturning(
      Map<String, Map<String, dynamic>> responses,
    ) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _RecordingAdapter(responses);
      dio.httpClientAdapter = adapter;
      return (
        ChatRepository(ApiClient(tokenStorage: FakeTokenStorage(), dio: dio)),
        adapter,
      );
    }

    test('getIcebreakers maps the lines and source', () async {
      final (repo, adapter) = repoReturning({
        '/chat/conversations/7/icebreakers': {
          'icebreakers': ['What got you into hiking?', 'Favourite trail?'],
          'source': 'ai',
        },
      });

      final set = await repo.getIcebreakers(7);

      expect(adapter.lastRequest!.method, 'GET');
      expect(set.lines, ['What got you into hiking?', 'Favourite trail?']);
      expect(set.isAi, isTrue);
    });

    test('refreshIcebreakers POSTs to the refresh path', () async {
      final (repo, adapter) = repoReturning({
        '/chat/conversations/7/icebreakers/refresh': {
          'icebreakers': ['Something new?'],
          'source': 'template',
        },
      });

      final set = await repo.refreshIcebreakers(7);

      expect(adapter.lastRequest!.method, 'POST');
      expect(
        adapter.lastRequest!.path,
        '/chat/conversations/7/icebreakers/refresh',
      );
      expect(set.isAi, isFalse);
    });
  });

  group('IcebreakerSuggestions', () {
    testWidgets('shows the lines for the right conversation', (tester) async {
      final chat = _FakeChat(
        load: () async =>
            _set(['What got you into hiking?', 'Favourite trail?']),
      );
      await _pump(tester, chat);

      expect(chat.ids, [42]);
      expect(find.text('Ideas to start the chat'), findsOneWidget);
      expect(find.text('What got you into hiking?'), findsOneWidget);
      expect(find.text('Favourite trail?'), findsOneWidget);
      expect(find.text('More ideas'), findsOneWidget);
    });

    testWidgets('tapping a line hands it to the parent, and sends nothing', (
      tester,
    ) async {
      final chat = _FakeChat(
        load: () async => _set(['What got you into hiking?']),
      );
      final picked = await _pump(tester, chat);

      await tester.tap(find.text('What got you into hiking?'));
      await tester.pump();

      expect(picked, ['What got you into hiking?']);
      // The widget's only jobs are to show and to report the pick; it has no
      // way to send anything (ChatRepository.sendMessage is not even mocked).
      expect(chat.refreshes, 0);
    });

    testWidgets('AI-written lines are labelled as AI', (tester) async {
      await _pump(
        tester,
        _FakeChat(load: () async => _set(['Line one here?'], source: 'ai')),
      );

      expect(find.text('AI'), findsOneWidget);
    });

    testWidgets('template lines carry no AI label', (tester) async {
      await _pump(
        tester,
        _FakeChat(load: () async => _set(['Line one here?'])),
      );

      expect(find.text('AI'), findsNothing);
    });

    testWidgets('More ideas swaps in a fresh set', (tester) async {
      final chat = _FakeChat(
        load: () async => _set(['First idea here?']),
        refresh: () async => _set(['A brand new idea?']),
      );
      await _pump(tester, chat);

      await tester.tap(find.text('More ideas'));
      await tester.pumpAndSettle();

      expect(chat.refreshes, 1);
      expect(find.text('First idea here?'), findsNothing);
      expect(find.text('A brand new idea?'), findsOneWidget);
    });

    testWidgets('More ideas cannot be spammed while one is in flight', (
      tester,
    ) async {
      final hold = Completer<IcebreakerSet>();
      final chat = _FakeChat(
        load: () async => _set(['First idea here?']),
        refresh: () => hold.future,
      );
      await _pump(tester, chat);

      await tester.tap(find.text('More ideas'));
      await tester.pump();
      await tester.tap(find.text('More ideas'), warnIfMissed: false);
      await tester.pump();

      expect(chat.refreshes, 1);
      hold.complete(_set(['Fresh?  one here']));
      await tester.pumpAndSettle();
    });

    testWidgets('a failed load takes no space and shows no error', (
      tester,
    ) async {
      final chat = _FakeChat(load: () async => throw _error('boom'));
      await _pump(tester, chat);

      expect(find.text('Ideas to start the chat'), findsNothing);
      expect(find.text('boom'), findsNothing);
      expect(tester.getSize(find.byType(IcebreakerSuggestions)).height, 0);
    });

    testWidgets('no lines at all shows nothing', (tester) async {
      await _pump(tester, _FakeChat(load: () async => _set(const [])));

      expect(find.text('Ideas to start the chat'), findsNothing);
    });

    testWidgets('a failed refresh tells them and keeps the current lines', (
      tester,
    ) async {
      final chat = _FakeChat(
        load: () async => _set(['First idea here?']),
        refresh: () async => throw _error('Too many requests', 429),
      );
      await _pump(tester, chat);

      await tester.tap(find.text('More ideas'));
      await tester.pumpAndSettle();

      expect(find.text('Too many requests'), findsOneWidget);
      expect(find.text('First idea here?'), findsOneWidget);
    });
  });
}
