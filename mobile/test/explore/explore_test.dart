import 'dart:async';
import 'dart:convert';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/core/network/api_exception.dart';
import 'package:datingapp/core/router/tab_refresh.dart';
import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/discovery/domain/candidate.dart';
import 'package:datingapp/explore/data/explore_repository.dart';
import 'package:datingapp/explore/domain/explore_interest.dart';
import 'package:datingapp/explore/presentation/explore_people_screen.dart';
import 'package:datingapp/explore/presentation/explore_screen.dart';
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

class _FakeExploreRepository implements ExploreRepository {
  _FakeExploreRepository({required this.interests, this.people});

  Future<List<ExploreInterest>> Function() interests;
  Future<ExplorePeoplePage> Function(int interestId)? people;
  int interestCalls = 0;
  final peopleRequests = <int>[];

  @override
  Future<List<ExploreInterest>> getInterests() {
    interestCalls++;
    return interests();
  }

  @override
  Future<ExplorePeoplePage> getPeople(
    int interestId, {
    int page = 1,
    int perPage = 20,
  }) {
    peopleRequests.add(interestId);
    return people!(interestId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ExploreInterest _interest(
  int id,
  String name, {
  String? category = 'Lifestyle',
  int count = 5,
  bool yours = false,
}) => ExploreInterest(
  id: id,
  name: name,
  category: category,
  memberCount: count,
  isYours: yours,
);

ExplorePeoplePage _people(List<DiscoveryCandidate> people, {int? total}) =>
    ExplorePeoplePage(
      people: people,
      total: total ?? people.length,
      hasMore: false,
    );

ApiException _apiError(String code, [String message = 'Nope']) =>
    ApiException(code: code, message: message, statusCode: 422);

/// The Explore tab plus stubs for everything it navigates to. The interest
/// stub records what it was opened with.
Widget _app(
  _FakeExploreRepository repo, {
  ProviderContainer? container,
  String initial = '/explore',
  ExploreInterest? peopleFor,
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/explore', builder: (_, _) => const ExploreScreen()),
      GoRoute(
        path: '/explore/interest',
        builder: (context, state) {
          final interest = state.extra! as ExploreInterest;
          return Scaffold(body: Text('people of ${interest.name}'));
        },
      ),
      GoRoute(
        path: '/people',
        builder: (_, _) => ExplorePeopleScreen(interest: peopleFor!),
      ),
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
        path: '/onboarding/location',
        builder: (_, _) => const Scaffold(body: Text('location page')),
      ),
      GoRoute(
        path: '/discover/filters',
        builder: (_, _) => const Scaffold(body: Text('filters page')),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container:
        container ??
        ProviderContainer(
          overrides: [exploreRepositoryProvider.overrideWithValue(repo)],
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
  group('ExploreRepository (docs/03 Explore)', () {
    (ExploreRepository, _FakeAdapter) repoReturning(
      Map<String, Map<String, dynamic>> responses,
    ) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _FakeAdapter(responses);
      dio.httpClientAdapter = adapter;
      return (
        ExploreRepository(
          ApiClient(tokenStorage: FakeTokenStorage(), dio: dio),
        ),
        adapter,
      );
    }

    test('getInterests maps tiles', () async {
      final (repo, _) = repoReturning({
        '/explore/interests': {
          'interests': [
            {
              'id': 3,
              'name': 'Coffee',
              'category': 'Food & drink',
              'member_count': 1,
              'is_yours': true,
            },
            {
              'id': 4,
              'name': 'Hiking',
              'category': null,
              'member_count': 12,
              'is_yours': false,
            },
          ],
        },
      });

      final interests = await repo.getInterests();

      expect(interests.map((i) => i.name), ['Coffee', 'Hiking']);
      expect(interests.first.isYours, isTrue);
      expect(interests.first.peopleLabel, '1 person');
      expect(interests.last.category, isNull);
      expect(interests.last.peopleLabel, '12 people');
    });

    test('getPeople hits the interest path and maps people', () async {
      final (repo, adapter) = repoReturning({
        '/explore/interests/3/people': {
          'interest': {'id': 3, 'name': 'Coffee', 'category': null},
          'total': 1,
          'people': [
            {
              'id': 5,
              'display_name': 'Ananya',
              'age': 29,
              'bio': null,
              'relationship_goal': null,
              'is_verified': false,
              'distance_km': 2,
              'shared_interests_count': 1,
              'shared_interests': ['Coffee'],
              'interests': ['Coffee'],
              'photos': [],
              'prompts': [],
            },
          ],
          'meta': {'page': 1, 'per_page': 20, 'has_more': true},
        },
      });

      final page = await repo.getPeople(3, page: 2);

      expect(adapter.lastRequest!.path, '/explore/interests/3/people');
      expect(adapter.lastRequest!.queryParameters, {'page': 2, 'per_page': 20});
      expect(page.total, 1);
      expect(page.hasMore, isTrue);
      expect(page.people.single.displayName, 'Ananya');
    });
  });

  group('ExploreScreen', () {
    testWidgets('a grid of interests with their people counts', (tester) async {
      final repo = _FakeExploreRepository(
        interests: () async => [
          _interest(1, 'Coffee', count: 88),
          _interest(2, 'Hiking', count: 1),
        ],
      );
      await _pump(tester, _app(repo));

      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Find people who share your interests'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('88 people'), findsOneWidget);
      expect(find.text('Hiking'), findsOneWidget);
      expect(find.text('1 person'), findsOneWidget);
    });

    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'a two-line name fits its tile on a narrow phone at ${scale}x text',
        (tester) async {
          final repo = _FakeExploreRepository(
            interests: () async => [
              _interest(1, 'Gym & fitness', category: 'Sports', count: 2),
              _interest(2, 'Volunteering', category: 'Lifestyle', count: 1),
            ],
          );
          tester.view.physicalSize = const Size(720, 1600);
          tester.view.devicePixelRatio = 2; // a 360-wide phone
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(_app(repo));
          await tester.pumpAndSettle();

          expect(find.text('Gym & fitness'), findsOneWidget);
          // A RenderFlex overflow is reported as an exception, not a failure.
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('an interest already on your profile carries a tick', (
      tester,
    ) async {
      final repo = _FakeExploreRepository(
        interests: () async => [
          _interest(1, 'Coffee', yours: true),
          _interest(2, 'Hiking'),
        ],
      );
      await _pump(tester, _app(repo));

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('category chips narrow the grid; All brings it back', (
      tester,
    ) async {
      final repo = _FakeExploreRepository(
        interests: () async => [
          _interest(1, 'Coffee', category: 'Food & drink'),
          _interest(2, 'Hiking', category: 'Sports'),
          _interest(3, 'Running', category: 'Sports'),
        ],
      );
      await _pump(tester, _app(repo));
      expect(find.text('All'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Sports'));
      await tester.pumpAndSettle();
      expect(find.text('Hiking'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets('search filters by name, case-insensitively, and closes', (
      tester,
    ) async {
      final repo = _FakeExploreRepository(
        interests: () async => [_interest(1, 'Coffee'), _interest(2, 'Hiking')],
      );
      await _pump(tester, _app(repo));

      await tester.tap(find.byTooltip('Search interests'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'HIK');
      await tester.pumpAndSettle();
      expect(find.text('Hiking'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No interests match that.'), findsOneWidget);

      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Hiking'), findsOneWidget);
    });

    testWidgets('tapping a tile opens its people, then refreshes counts', (
      tester,
    ) async {
      final repo = _FakeExploreRepository(
        interests: () async => [_interest(1, 'Coffee')],
      );
      await _pump(tester, _app(repo));
      expect(repo.interestCalls, 1);

      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();
      expect(find.text('people of Coffee'), findsOneWidget);

      GoRouter.of(tester.element(find.text('people of Coffee'))).pop();
      await tester.pumpAndSettle();
      expect(repo.interestCalls, 2);
    });

    testWidgets('no interests yet is an empty state', (tester) async {
      final repo = _FakeExploreRepository(interests: () async => []);
      await _pump(tester, _app(repo));

      expect(find.text('Nothing to explore yet'), findsOneWidget);
    });

    testWidgets('no location: guidance that opens the location screen', (
      tester,
    ) async {
      final repo = _FakeExploreRepository(
        interests: () async => throw _apiError('location_required'),
      );
      await _pump(tester, _app(repo));

      expect(
        find.text('Turn on location to explore people nearby.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Set location'));
      await tester.pumpAndSettle();
      expect(find.text('location page'), findsOneWidget);
    });

    testWidgets('no preferences: guidance that opens Filters', (tester) async {
      final repo = _FakeExploreRepository(
        interests: () async => throw _apiError('preferences_required'),
      );
      await _pump(tester, _app(repo));

      await tester.tap(find.text('Set preferences'));
      await tester.pumpAndSettle();
      expect(find.text('filters page'), findsOneWidget);
    });

    testWidgets('an error shows Retry, and Retry recovers', (tester) async {
      var attempt = 0;
      final repo = _FakeExploreRepository(
        interests: () async {
          attempt++;
          if (attempt == 1) throw _apiError('server_error', 'Server down');
          return [_interest(1, 'Coffee')];
        },
      );
      await _pump(tester, _app(repo));
      expect(find.text('Server down'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets('re-selecting the tab reloads without a spinner', (
      tester,
    ) async {
      final hold = Completer<List<ExploreInterest>>();
      var calls = 0;
      final repo = _FakeExploreRepository(
        interests: () {
          calls++;
          return calls == 1
              ? Future.value([_interest(1, 'Coffee')])
              : hold.future;
        },
      );
      final container = ProviderContainer(
        overrides: [exploreRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await _pump(tester, _app(repo, container: container));

      container.read(exploreTabRefreshProvider.notifier).bump();
      await tester.pump();

      // Second load in flight: the grid stays, no spinner.
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      hold.complete([_interest(1, 'Coffee', count: 9)]);
      await tester.pumpAndSettle();
      expect(find.text('9 people'), findsOneWidget);
    });
  });

  group('ExplorePeopleScreen', () {
    final coffee = _interest(3, 'Coffee');

    Future<void> openPeople(WidgetTester tester, _FakeExploreRepository repo) =>
        _pump(tester, _app(repo, initial: '/people', peopleFor: coffee));

    testWidgets('lists the people for that interest with a count', (
      tester,
    ) async {
      final repo = _FakeExploreRepository(
        interests: () async => [],
        people: (_) async => _people([
          fakeCandidate(id: 1, name: 'Priya', age: 26),
          fakeCandidate(id: 2, name: 'Ananya', age: 29),
        ]),
      );
      await openPeople(tester, repo);

      expect(repo.peopleRequests, [3]);
      expect(find.text('Coffee'), findsOneWidget); // app bar title
      expect(find.text('2 people share this'), findsOneWidget);
      expect(find.text('Priya, 26'), findsOneWidget);
      expect(find.text('Ananya, 29'), findsOneWidget);
    });

    testWidgets('a tapped person opens with Like / Pass enabled', (
      tester,
    ) async {
      final repo = _FakeExploreRepository(
        interests: () async => [],
        people: (_) async => _people([fakeCandidate()]),
      );
      await openPeople(tester, repo);

      await tester.tap(find.text('Priya, 26'));
      await tester.pumpAndSettle();

      expect(find.text('detail Priya respond=true'), findsOneWidget);
    });

    testWidgets('answering someone drops them and lowers the count', (
      tester,
    ) async {
      final repo = _FakeExploreRepository(
        interests: () async => [],
        people: (_) async => _people([
          fakeCandidate(id: 1, name: 'Priya'),
          fakeCandidate(id: 2, name: 'Ananya', age: 29),
        ]),
      );
      await openPeople(tester, repo);

      await tester.tap(find.text('Priya, 26'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('answer'));
      await tester.pumpAndSettle();

      expect(find.text('Priya, 26'), findsNothing);
      expect(find.text('Ananya, 29'), findsOneWidget);
      expect(find.text('1 person shares this'), findsOneWidget);
    });

    testWidgets('when everyone is answered, an empty state points back', (
      tester,
    ) async {
      final repo = _FakeExploreRepository(
        interests: () async => [],
        people: (_) async => _people(const []),
      );
      await openPeople(tester, repo);

      expect(find.text("You've seen everyone here"), findsOneWidget);
      expect(find.text('Back to Explore'), findsOneWidget);
    });

    testWidgets('an error shows Retry, and Retry recovers', (tester) async {
      var attempt = 0;
      final repo = _FakeExploreRepository(
        interests: () async => [],
        people: (_) async {
          attempt++;
          if (attempt == 1) throw _apiError('server_error', 'Server down');
          return _people([fakeCandidate()]);
        },
      );
      await openPeople(tester, repo);
      expect(find.text('Server down'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Priya, 26'), findsOneWidget);
    });
  });
}
