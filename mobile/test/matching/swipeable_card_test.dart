import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/discovery/domain/candidate.dart';
import 'package:datingapp/matching/domain/swipe_direction.dart';
import 'package:datingapp/matching/presentation/swipeable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DiscoveryCandidate _candidate({
  String? bio = 'Weekend hiker.',
  bool verified = true,
  List<String> interests = const ['Hiking', 'Live music'],
}) => DiscoveryCandidate(
  id: 7,
  displayName: 'Sonia',
  age: 29,
  bio: bio,
  relationshipGoal: null,
  isVerified: verified,
  distanceKm: 6,
  sharedInterestsCount: interests.length,
  sharedInterests: interests,
  photos: const [], // no network in tests — exercises the placeholder path
);

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(20), child: child),
  ),
);

void main() {
  group('SwipeableCard content', () {
    testWidgets('shows name, age, distance, bio and shared interests', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(SwipeableCard(candidate: _candidate(), onSwiped: (_) {})),
      );

      expect(find.text('Sonia, 29'), findsOneWidget);
      expect(find.text('6 km away'), findsOneWidget);
      expect(find.text('Weekend hiker.'), findsOneWidget);
      expect(find.text('Hiking'), findsOneWidget);
      expect(find.text('Live music'), findsOneWidget);
    });

    testWidgets('shows a verified badge only for a verified candidate', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(SwipeableCard(candidate: _candidate(), onSwiped: (_) {})),
      );
      expect(find.byIcon(Icons.verified), findsOneWidget);

      await tester.pumpWidget(
        _host(
          SwipeableCard(
            candidate: _candidate(verified: false),
            onSwiped: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.verified), findsNothing);
    });

    testWidgets('caps interest chips at three and omits an empty bio', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SwipeableCard(
            candidate: _candidate(
              bio: null,
              interests: const ['A', 'B', 'C', 'D'],
            ),
            onSwiped: (_) {},
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsNothing);
      expect(find.text('Weekend hiker.'), findsNothing);
    });

    testWidgets('renders in the dark theme too', (tester) async {
      await tester.pumpWidget(
        _host(
          SwipeableCard(candidate: _candidate(), onSwiped: (_) {}),
          theme: AppTheme.dark,
        ),
      );
      expect(find.text('Sonia, 29'), findsOneWidget);
    });
  });

  group('SwipeableCard gestures', () {
    testWidgets('a drag past the threshold reports the swipe direction', (
      tester,
    ) async {
      SwipeDirection? swiped;
      await tester.pumpWidget(
        _host(
          SwipeableCard(candidate: _candidate(), onSwiped: (d) => swiped = d),
        ),
      );

      await tester.drag(find.byType(SwipeableCard), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(swiped, SwipeDirection.right);
    });

    testWidgets('a short drag springs back without swiping', (tester) async {
      SwipeDirection? swiped;
      await tester.pumpWidget(
        _host(
          SwipeableCard(candidate: _candidate(), onSwiped: (d) => swiped = d),
        ),
      );

      await tester.drag(find.byType(SwipeableCard), const Offset(-40, 0));
      await tester.pumpAndSettle();

      expect(swiped, isNull);
    });

    testWidgets('reports drag progress for the card behind it', (tester) async {
      final progress = ValueNotifier<double>(0);
      await tester.pumpWidget(
        _host(
          SwipeableCard(
            candidate: _candidate(),
            dragProgress: progress,
            onSwiped: (_) {},
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SwipeableCard)),
      );
      await gesture.moveBy(const Offset(55, 0));
      await tester.pump();
      expect(progress.value, closeTo(0.5, 0.05));
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
