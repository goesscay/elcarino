import 'dart:async';
import 'dart:convert';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/core/network/api_exception.dart';
import 'package:datingapp/core/router/tab_refresh.dart';
import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/discovery/domain/candidate.dart';
import 'package:datingapp/likes/data/likes_repository.dart';
import 'package:datingapp/likes/domain/likes_page.dart';
import 'package:datingapp/likes/presentation/likes_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/candidate_fixture.dart';
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
    return ResponseBody.fromString(
      jsonEncode(responses[options.path] ?? {}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeLikesRepository implements LikesRepository {
  _FakeLikesRepository({required this.received, required this.sent});

  Future<LikesPage> Function() received;
  Future<LikesPage> Function() sent;
  int receivedCalls = 0;
  int sentCalls = 0;

  @override
  Future<LikesPage> getReceived({int page = 1, int perPage = 20}) {
    receivedCalls++;
    return received();
  }

  @override
  Future<LikesPage> getSent({int page = 1, int perPage = 20}) {
    sentCalls++;
    return sent();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LikesPage _page(
  List<DiscoveryCandidate> likes, {
  int? total,
  bool locked = false,
}) => LikesPage(
  likes: likes,
  total: total ?? likes.length,
  hasMore: false,
  locked: locked,
);

/// `/likes` plus stubs for everything it navigates to. The detail stub reports
/// the `canRespond` flag it was opened with and can pop `true`, like the real
/// screen does once someone's been answered.
Widget _app(_FakeLikesRepository repo, {ProviderContainer? container}) {
  final router = GoRouter(
    initialLocation: '/likes',
    routes: [
      GoRoute(path: '/likes', builder: (_, _) => const LikesScreen()),
      GoRoute(
        path: '/profile/candidate',
        builder: (context, state) {
          final (candidate, canRespond) =
              state.extra! as (DiscoveryCandidate, bool);
          return Scaffold(
            body: Column(
              children: [
                Text('detail ${candidate.displayName} respond=$canRespond'),
                TextButton(
                  onPressed: () => context.pop(true),
                  child: const Text('answer'),
                ),
              ],
            ),
          );
        },
      ),
      GoRoute(
        path: '/settings/subscription',
        builder: (_, _) => const Scaffold(body: Text('subscription page')),
      ),
      GoRoute(
        path: '/discover',
        builder: (_, _) => const Scaffold(body: Text('discover page')),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container:
        container ??
        ProviderContainer(
          overrides: [likesRepositoryProvider.overrideWithValue(repo)],
        ),
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  group('LikesRepository (docs/03 Likes)', () {
    (LikesRepository, _FakeAdapter) repoReturning(
      Map<String, Map<String, dynamic>> responses,
    ) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _FakeAdapter(responses);
      dio.httpClientAdapter = adapter;
      return (
        LikesRepository(ApiClient(tokenStorage: FakeTokenStorage(), dio: dio)),
        adapter,
      );
    }

    const meta = {'page': 1, 'per_page': 20, 'has_more': false};

    test('a locked page carries the count and no people', () async {
      final (repo, adapter) = repoReturning({
        '/likes/received': {
          'locked': true,
          'total': 7,
          'likes': [],
          'meta': meta,
        },
      });

      final page = await repo.getReceived();

      expect(page.locked, isTrue);
      expect(page.total, 7);
      expect(page.likes, isEmpty);
      expect(adapter.lastRequest!.queryParameters, {'page': 1, 'per_page': 20});
    });

    test(
      'maps people, null distance, interests, prompts and liked_at',
      () async {
        final (repo, _) = repoReturning({
          '/likes/sent': {
            'total': 1,
            'likes': [
              {
                'id': 5,
                'display_name': 'Ananya',
                'age': 29,
                'bio': null,
                'relationship_goal': 'Serious relationship',
                'is_verified': true,
                'distance_km': null,
                'shared_interests_count': 1,
                'shared_interests': ['Coffee'],
                'interests': ['Coffee', 'Hiking'],
                'photos': [],
                'prompts': [
                  {'prompt_id': 1, 'prompt': 'A perfect day', 'answer': 'Rain'},
                ],
                'liked_at': '2026-09-19T10:00:00+00:00',
              },
            ],
            'meta': meta,
          },
        });

        final page = await repo.getSent();
        final person = page.likes.single;

        expect(page.locked, isFalse);
        expect(person.distanceKm, isNull);
        expect(person.distanceLabel, isNull);
        expect(person.interests, ['Coffee', 'Hiking']);
        expect(person.prompts.single.answer, 'Rain');
        expect(person.likedAt, DateTime.utc(2026, 9, 19, 10));
      },
    );
  });

  group('LikesScreen', () {
    testWidgets('free: a count and an upgrade prompt, and no people', (
      tester,
    ) async {
      final repo = _FakeLikesRepository(
        received: () async => _page(const [], total: 3, locked: true),
        sent: () async => _page(const []),
      );
      await _pump(tester, _app(repo));

      expect(find.text('3 people like you'), findsOneWidget);
      expect(find.text('Upgrade to see who likes you'), findsOneWidget);
      expect(find.text('See who likes you'), findsOneWidget);
      // The header badge carries the same count.
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('free with one like uses the singular', (tester) async {
      final repo = _FakeLikesRepository(
        received: () async => _page(const [], total: 1, locked: true),
        sent: () async => _page(const []),
      );
      await _pump(tester, _app(repo));

      expect(find.text('1 person likes you'), findsOneWidget);
    });

    testWidgets('free with no likes is an empty state, not a paywall', (
      tester,
    ) async {
      final repo = _FakeLikesRepository(
        received: () async => _page(const [], total: 0, locked: true),
        sent: () async => _page(const []),
      );
      await _pump(tester, _app(repo));

      expect(find.text('No likes yet'), findsOneWidget);
      expect(find.text('See who likes you'), findsNothing);
    });

    testWidgets('the upgrade button opens Subscription, then reloads', (
      tester,
    ) async {
      final repo = _FakeLikesRepository(
        received: () async => _page(const [], total: 2, locked: true),
        sent: () async => _page(const []),
      );
      await _pump(tester, _app(repo));
      expect(repo.receivedCalls, 1);

      await tester.tap(find.text('See who likes you'));
      await tester.pumpAndSettle();
      expect(find.text('subscription page'), findsOneWidget);

      // Back from the paywall — they may have subscribed, so it re-asks.
      GoRouter.of(tester.element(find.text('subscription page'))).pop();
      await tester.pumpAndSettle();
      expect(repo.receivedCalls, 2);
    });

    testWidgets('subscriber: a grid of people with name, age and distance', (
      tester,
    ) async {
      final repo = _FakeLikesRepository(
        received: () async => _page([
          fakeCandidate(id: 1, name: 'Priya', age: 26, distanceKm: 3),
          fakeCandidate(id: 2, name: 'Ananya', age: 29, distanceKm: 0),
        ]),
        sent: () async => _page(const []),
      );
      await _pump(tester, _app(repo));

      expect(find.text('Priya, 26'), findsOneWidget);
      expect(find.text('3 km away'), findsOneWidget);
      expect(find.text('Ananya, 29'), findsOneWidget);
      expect(find.text('less than 1 km away'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // header badge
      expect(find.text('Upgrade to see who likes you'), findsNothing);
    });

    testWidgets('a person with no known distance shows no distance line', (
      tester,
    ) async {
      final repo = _FakeLikesRepository(
        received: () async => _page([fakeCandidate(distanceKm: null)]),
        sent: () async => _page(const []),
      );
      await _pump(tester, _app(repo));

      expect(find.text('Priya, 26'), findsOneWidget);
      expect(find.textContaining('km away'), findsNothing);
    });

    testWidgets('tapping a tile opens the detail with Like / Pass enabled', (
      tester,
    ) async {
      final repo = _FakeLikesRepository(
        received: () async => _page([fakeCandidate()]),
        sent: () async => _page(const []),
      );
      await _pump(tester, _app(repo));

      await tester.tap(find.text('Priya, 26'));
      await tester.pumpAndSettle();

      expect(find.text('detail Priya respond=true'), findsOneWidget);
    });

    testWidgets('answering someone drops them from the grid and the count', (
      tester,
    ) async {
      final repo = _FakeLikesRepository(
        received: () async => _page([
          fakeCandidate(id: 1, name: 'Priya'),
          fakeCandidate(id: 2, name: 'Ananya', age: 29),
        ]),
        sent: () async => _page(const []),
      );
      await _pump(tester, _app(repo));

      await tester.tap(find.text('Priya, 26'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('answer'));
      await tester.pumpAndSettle();

      expect(find.text('Priya, 26'), findsNothing);
      expect(find.text('Ananya, 29'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // badge 2 -> 1
    });

    testWidgets('People you like: free, read-only, no Like / Pass', (
      tester,
    ) async {
      final repo = _FakeLikesRepository(
        received: () async => _page(const [], total: 5, locked: true),
        sent: () async => _page([fakeCandidate(name: 'Meera', age: 31)]),
      );
      await _pump(tester, _app(repo));

      await tester.tap(find.text('People you like'));
      await tester.pumpAndSettle();
      expect(find.text('Meera, 31'), findsOneWidget);

      await tester.tap(find.text('Meera, 31'));
      await tester.pumpAndSettle();
      expect(find.text('detail Meera respond=false'), findsOneWidget);
    });

    testWidgets('People you like, empty, points back to Discover', (
      tester,
    ) async {
      final repo = _FakeLikesRepository(
        received: () async => _page(const [], total: 0),
        sent: () async => _page(const []),
      );
      await _pump(tester, _app(repo));

      await tester.tap(find.text('People you like'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing waiting'), findsOneWidget);

      await tester.tap(find.text('Keep discovering'));
      await tester.pumpAndSettle();
      expect(find.text('discover page'), findsOneWidget);
    });

    testWidgets('an error shows Retry, and Retry recovers', (tester) async {
      var attempt = 0;
      final repo = _FakeLikesRepository(
        received: () async {
          attempt++;
          if (attempt == 1) {
            throw ApiException(
              code: 'server_error',
              message: 'Server unavailable',
              statusCode: 500,
            );
          }
          return _page([fakeCandidate()]);
        },
        sent: () async => _page(const []),
      );
      await _pump(tester, _app(repo));
      expect(find.text('Server unavailable'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Priya, 26'), findsOneWidget);
    });

    testWidgets('reloading an empty list keeps it on screen, no spinner', (
      tester,
    ) async {
      final hold = Completer<LikesPage>();
      var calls = 0;
      final repo = _FakeLikesRepository(
        received: () {
          calls++;
          return calls == 1 ? Future.value(_page(const [])) : hold.future;
        },
        sent: () async => _page(const []),
      );
      final container = ProviderContainer(
        overrides: [likesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await _pump(tester, _app(repo, container: container));
      expect(find.text('No likes yet'), findsOneWidget);

      container.read(likesTabRefreshProvider.notifier).bump();
      await tester.pump();

      // The second load is still in flight: the empty state stays put.
      expect(find.text('No likes yet'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      hold.complete(_page(const []));
      await tester.pumpAndSettle();
    });

    testWidgets('re-selecting the Likes tab reloads both lists', (
      tester,
    ) async {
      final repo = _FakeLikesRepository(
        received: () async => _page([fakeCandidate()]),
        sent: () async => _page(const []),
      );
      final container = ProviderContainer(
        overrides: [likesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await _pump(tester, _app(repo, container: container));
      expect((repo.receivedCalls, repo.sentCalls), (1, 1));

      container.read(likesTabRefreshProvider.notifier).bump();
      await tester.pumpAndSettle();

      expect((repo.receivedCalls, repo.sentCalls), (2, 2));
    });
  });
}
