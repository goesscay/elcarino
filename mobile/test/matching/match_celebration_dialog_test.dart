import 'package:datingapp/chat/domain/conversation.dart';
import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/discovery/domain/candidate.dart';
import 'package:datingapp/matching/domain/match.dart';
import 'package:datingapp/matching/presentation/match_celebration_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _candidate = DiscoveryCandidate(
  id: 7,
  displayName: 'Sonia',
  age: 29,
  bio: null,
  relationshipGoal: null,
  isVerified: false,
  distanceKm: 4,
  sharedInterestsCount: 0,
  sharedInterests: [],
  photos: [], // no network in tests — placeholders render instead
);

const _conversation = Conversation(
  id: 5,
  matchId: 1,
  otherUser: MatchedUser(
    id: 7,
    displayName: 'Sonia',
    age: 29,
    bio: null,
    isVerified: false,
    photos: [],
  ),
  lastMessageAt: null,
  lastMessagePreview: null,
  unreadCount: 0,
  requiresSubscriptionToMessage: false,
);

/// A one-button host that opens the celebration, inside a real router so the
/// "Send a message" navigation can be observed.
Widget _host({Conversation? conversation, String? myPhotoUrl}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMatchCelebration(
                context,
                _candidate,
                conversation: conversation,
                myPhotoUrl: myPhotoUrl,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) =>
            Scaffold(body: Text('chat ${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

Future<void> _open(WidgetTester tester, Widget host) async {
  // Reduce-motion on: the celebration lands on its final frame, so the test
  // doesn't depend on animation timing.
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: host,
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the celebration copy and both actions', (tester) async {
    await _open(tester, _host(conversation: _conversation));

    expect(find.text("It's a Match!"), findsOneWidget);
    expect(find.text('You both liked each other.'), findsOneWidget);
    expect(find.text('Send a message'), findsOneWidget);
    expect(find.text('Keep discovering'), findsOneWidget);
  });

  testWidgets('renders both photo slots even with no photos or URL', (
    tester,
  ) async {
    await _open(tester, _host(conversation: _conversation));

    // One placeholder per person — the celebration never blocks on a photo.
    expect(find.byIcon(Icons.person_outline), findsNWidgets(2));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('Keep discovering closes it without navigating', (tester) async {
    await _open(tester, _host(conversation: _conversation));

    await tester.tap(find.text('Keep discovering'));
    await tester.pumpAndSettle();

    expect(find.text("It's a Match!"), findsNothing);
    expect(find.text('chat 5'), findsNothing);
  });

  testWidgets('Send a message closes it and opens that conversation', (
    tester,
  ) async {
    await _open(tester, _host(conversation: _conversation));

    await tester.tap(find.text('Send a message'));
    await tester.pumpAndSettle();

    expect(find.text('chat 5'), findsOneWidget);
  });

  testWidgets('Send a message with no conversation shows a notice instead', (
    tester,
  ) async {
    await _open(tester, _host());

    await tester.tap(find.text('Send a message'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't open the chat"), findsOneWidget);
    expect(find.text('chat 5'), findsNothing);
  });
}
