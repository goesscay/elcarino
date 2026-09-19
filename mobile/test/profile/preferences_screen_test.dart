import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/onboarding/presentation/preferences_screen.dart';
import 'package:datingapp/profile/data/profile_repository.dart';
import 'package:datingapp/profile/domain/gender.dart';
import 'package:datingapp/profile/domain/preferences.dart';
import 'package:datingapp/subscriptions/data/subscription_repository.dart';
import 'package:datingapp/subscriptions/domain/subscription.dart';
import 'package:datingapp/subscriptions/domain/subscription_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo(this.saved);

  final Preferences? saved;
  Preferences? updated;

  @override
  Future<Preferences?> getPreferences() async => saved;

  @override
  Future<Preferences> updatePreferences(Preferences preferences) async {
    updated = preferences;
    return preferences;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubscriptionRepo implements SubscriptionRepository {
  _FakeSubscriptionRepo(this.current);

  final Subscription? current;

  @override
  Future<Subscription?> getCurrent() async => current;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _saved = Preferences(
  minAge: 25,
  maxAge: 35,
  maxDistanceKm: 30,
  interestedInGenders: [Gender.woman],
);

Subscription _premium() => Subscription(
  id: 1,
  status: 'active',
  provider: 'log',
  startedAt: DateTime(2026, 1, 1),
  endsAt: DateTime.now().add(const Duration(days: 30)),
  plan: const SubscriptionPlan(
    id: 1,
    name: 'Premium',
    priceCents: 999,
    currency: 'USD',
    billingInterval: 'monthly',
    entitlements: {'advanced_filters': true},
  ),
);

Future<(_FakeProfileRepo, List<int>)> _pump(
  WidgetTester tester, {
  Preferences? saved = _saved,
  Subscription? subscription,
  String label = 'Show people',
  String title = 'Filters',
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = _FakeProfileRepo(saved);
  final done = <int>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        subscriptionRepositoryProvider.overrideWithValue(
          _FakeSubscriptionRepo(subscription),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: PreferencesScreen(
          step: null,
          title: title,
          continueLabel: label,
          onDone: () => done.add(1),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, done);
}

void _setDistance(WidgetTester tester, double km) =>
    tester.widget<Slider>(find.byType(Slider)).onChanged!(km);

void main() {
  testWidgets('loads the saved preferences into the form', (tester) async {
    await _pump(tester);

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('25 – 35'), findsOneWidget);
    expect(find.text('30 km'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Woman'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Man'))
          .selected,
      isFalse,
    );
  });

  testWidgets('Reset only appears once something changed, and reverts it', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Reset'), findsNothing);

    _setDistance(tester, 120);
    await tester.pump();
    expect(find.text('120 km'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(find.text('30 km'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);
  });

  testWidgets('Reset also puts back a changed "interested in" choice', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Man'));
    await tester.pump();
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Man'))
          .selected,
      isFalse,
    );
  });

  testWidgets('the primary button saves the edited values, then finishes', (
    tester,
  ) async {
    final (repo, done) = await _pump(tester);

    _setDistance(tester, 80);
    await tester.pump();
    await tester.tap(find.text('Show people'));
    await tester.pumpAndSettle();

    expect(repo.updated?.maxDistanceKm, 80);
    expect(repo.updated?.minAge, 25);
    expect(repo.updated?.maxAge, 35);
    expect(repo.updated?.interestedInGenders, [Gender.woman]);
    expect(done, [1]);
  });

  testWidgets('needs at least one "interested in" option to save', (
    tester,
  ) async {
    final (repo, done) = await _pump(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Woman')); // deselect
    await tester.pump();
    await tester.tap(find.text('Show people'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Choose at least one'), findsOneWidget);
    expect(repo.updated, isNull);
    expect(done, isEmpty);
  });

  testWidgets('first-time setup starts from defaults with the given label', (
    tester,
  ) async {
    await _pump(tester, saved: null, label: 'Continue', title: 'Preferences');

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('21 – 40'), findsOneWidget);
    expect(find.text('50 km'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);
  });

  group('advanced filters', () {
    testWidgets('are locked for a non-subscriber, with an Upgrade path', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Premium'), findsOneWidget);
      await tester.tap(find.text('Advanced filters'));
      await tester.pumpAndSettle();

      expect(find.text('Upgrade'), findsOneWidget);
      final add = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_rounded).first,
      );
      expect(add.onPressed, isNull);
    });

    testWidgets('a subscriber can add a religion filter and it is saved', (
      tester,
    ) async {
      final (repo, _) = await _pump(tester, subscription: _premium());

      expect(find.text('Premium'), findsNothing);
      await tester.tap(find.text('Advanced filters'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Religion'),
        'Buddhist',
      );
      await tester.tap(find.byTooltip('Add religion filter'));
      await tester.pump();
      expect(find.widgetWithText(Chip, 'Buddhist'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      await tester.tap(find.text('Show people'));
      await tester.pumpAndSettle();

      expect(repo.updated?.religionFilter, ['Buddhist']);
    });
  });
}
