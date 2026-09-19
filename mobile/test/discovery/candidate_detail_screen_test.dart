import 'package:datingapp/chat/data/chat_repository.dart';
import 'package:datingapp/chat/domain/conversation.dart';
import 'package:datingapp/core/network/api_exception.dart';
import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/core/widgets/network_photo.dart';
import 'package:datingapp/discovery/domain/candidate.dart';
import 'package:datingapp/discovery/presentation/candidate_detail_screen.dart';
import 'package:datingapp/matching/data/matching_repository.dart';
import 'package:datingapp/matching/domain/swipe_direction.dart';
import 'package:datingapp/profile/data/profile_repository.dart';
import 'package:datingapp/profile/domain/profile.dart';
import 'package:datingapp/profile/domain/prompt.dart';
import 'package:datingapp/safety/data/safety_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/candidate_fixture.dart';

class _FakeMatching implements MatchingRepository {
  final swipes = <(int, SwipeDirection)>[];
  bool matched = false;
  ApiException? failure;

  @override
  Future<SwipeResult> swipe({
    required int targetId,
    required SwipeDirection direction,
  }) async {
    if (failure != null) throw failure!;
    swipes.add((targetId, direction));
    return SwipeResult(matched: matched, matchId: matched ? 9 : null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSafety implements SafetyRepository {
  final blocked = <int>[];

  @override
  Future<void> block(int userId) async => blocked.add(userId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChat implements ChatRepository {
  @override
  Future<List<Conversation>> getConversations() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfiles implements ProfileRepository {
  @override
  Future<Profile?> getProfile() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A launcher page that opens the detail and prints what it popped with, plus a
/// stub for the Report route so its `extra` can be checked.
class _Host {
  _Host(this.candidate, {this.canRespond = true});

  final DiscoveryCandidate candidate;
  final bool canRespond;
  final matching = _FakeMatching();
  final safety = _FakeSafety();
  Object? reportExtra;

  Widget build() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: _Launcher(
                onOpen: () => context.push<bool>('/detail'),
                result: (v) => v,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/detail',
          builder: (_, _) => CandidateDetailScreen(
            candidate: candidate,
            canRespond: canRespond,
          ),
        ),
        GoRoute(
          path: '/safety/report',
          builder: (context, state) {
            reportExtra = state.extra;
            return const Scaffold(body: Text('report page'));
          },
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        matchingRepositoryProvider.overrideWithValue(matching),
        safetyRepositoryProvider.overrideWithValue(safety),
        chatRepositoryProvider.overrideWithValue(_FakeChat()),
        profileRepositoryProvider.overrideWithValue(_FakeProfiles()),
      ],
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    );
  }
}

class _Launcher extends StatefulWidget {
  const _Launcher({required this.onOpen, required this.result});

  final Future<bool?>? Function() onOpen;
  final Object? Function(bool?) result;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  String _popped = 'not opened';

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        onPressed: () async {
          final v = await widget.onOpen();
          setState(() => _popped = 'popped $v');
        },
        child: const Text('open'),
      ),
      Text(_popped),
    ],
  );
}

Future<void> _open(WidgetTester tester, _Host host) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host.build());
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('CandidateDetailScreen', () {
    testWidgets('shows who they are, bio, goal, distance and interests', (
      tester,
    ) async {
      await _open(
        tester,
        _Host(
          fakeCandidate(
            name: 'Priya',
            age: 26,
            distanceKm: 4,
            verified: true,
            bio: 'Coffee, hikes and bad puns.',
            goal: 'Serious relationship',
            interests: ['Coffee', 'Hiking', 'Reading'],
            shared: ['Coffee'],
          ),
        ),
      );

      expect(find.text('Priya, 26'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.text('4 km away'), findsOneWidget);
      expect(find.text('Serious relationship'), findsOneWidget);
      expect(find.text('Coffee, hikes and bad puns.'), findsOneWidget);
      for (final interest in ['Coffee', 'Hiking', 'Reading']) {
        expect(find.text(interest), findsOneWidget);
      }
      expect(find.text('Highlighted: you have 1 in common.'), findsOneWidget);
    });

    testWidgets('omits what is not there: no distance, bio, goal, interests', (
      tester,
    ) async {
      await _open(tester, _Host(fakeCandidate(distanceKm: null)));

      expect(find.textContaining('km away'), findsNothing);
      expect(find.text('Interests'), findsNothing);
      expect(find.byIcon(Icons.verified), findsNothing);
    });

    testWidgets(
      'lays out prompts between the remaining photos, dropping none',
      (tester) async {
        await _open(
          tester,
          _Host(
            fakeCandidate(
              photos: 3,
              prompts: const [
                AnsweredPrompt(
                  promptId: 1,
                  promptText: 'A perfect day',
                  answer: 'Rain and a book',
                ),
              ],
            ),
          ),
        );

        expect(find.text('A perfect day'), findsOneWidget);
        expect(find.text('Rain and a book'), findsOneWidget);
        // The hero plus the two remaining photos.
        expect(
          find.byType(NetworkPhoto, skipOffstage: false),
          findsNWidgets(3),
        );
      },
    );

    testWidgets('Like swipes right, and the screen pops with true', (
      tester,
    ) async {
      final host = _Host(fakeCandidate(id: 7));
      await _open(tester, host);

      await tester.tap(find.text('Like'));
      await tester.pumpAndSettle();

      expect(host.matching.swipes, [(7, SwipeDirection.right)]);
      expect(find.text('popped true'), findsOneWidget);
    });

    testWidgets('Pass swipes left', (tester) async {
      final host = _Host(fakeCandidate(id: 7));
      await _open(tester, host);

      await tester.tap(find.text('Pass'));
      await tester.pumpAndSettle();

      expect(host.matching.swipes, [(7, SwipeDirection.left)]);
      expect(find.text('popped true'), findsOneWidget);
    });

    testWidgets('a mutual like plays the match celebration before popping', (
      tester,
    ) async {
      final host = _Host(fakeCandidate(id: 7, name: 'Priya'));
      host.matching.matched = true;
      await _open(tester, host);

      await tester.tap(find.text('Like'));
      // Not pumpAndSettle: the Like button's busy spinner keeps animating
      // behind the celebration until the screen pops.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text("It's a Match!"), findsOneWidget);
      // Still on the detail until the celebration is dismissed.
      expect(find.text('popped true'), findsNothing);

      await tester.tap(find.text('Keep discovering'));
      await tester.pumpAndSettle();
      expect(find.text('popped true'), findsOneWidget);
    });

    testWidgets('a failed swipe shows the message and stays put', (
      tester,
    ) async {
      final host = _Host(fakeCandidate());
      host.matching.failure = ApiException(
        code: 'too_many_requests',
        message: 'Slow down',
        statusCode: 429,
      );
      await _open(tester, host);

      await tester.tap(find.text('Like'));
      await tester.pumpAndSettle();

      expect(find.text('Slow down'), findsOneWidget);
      expect(find.text('popped true'), findsNothing);
      // Buttons come back so they can try again.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('read-only mode (People you like) has no Like / Pass', (
      tester,
    ) async {
      await _open(tester, _Host(fakeCandidate(), canRespond: false));

      expect(find.text('Like'), findsNothing);
      expect(find.text('Pass'), findsNothing);
      expect(find.text('Priya, 26'), findsOneWidget);
    });

    testWidgets('Report opens the report screen for this person', (
      tester,
    ) async {
      final host = _Host(fakeCandidate(id: 7, name: 'Priya'));
      await _open(tester, host);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      expect(find.text('report page'), findsOneWidget);
      expect(host.reportExtra, (7, 'Priya'));
    });

    testWidgets('Block asks first, blocks, then pops with true', (
      tester,
    ) async {
      final host = _Host(fakeCandidate(id: 7, name: 'Priya'));
      await _open(tester, host);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(find.text('Block Priya?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();

      expect(host.safety.blocked, [7]);
      expect(find.text('popped true'), findsOneWidget);
    });

    testWidgets('cancelling the Block dialog blocks nobody', (tester) async {
      final host = _Host(fakeCandidate(id: 7, name: 'Priya'));
      await _open(tester, host);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(host.safety.blocked, isEmpty);
      expect(find.text('Priya, 26'), findsOneWidget);
    });

    testWidgets('Back leaves without a result', (tester) async {
      await _open(tester, _Host(fakeCandidate()));

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('popped null'), findsOneWidget);
    });
  });
}
