import 'package:datingapp/core/auth/auth_controller.dart';
import 'package:datingapp/core/network/api_exception.dart';
import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/safety/data/safety_repository.dart';
import 'package:datingapp/safety/domain/blocked_user.dart';
import 'package:datingapp/safety/presentation/blocked_users_screen.dart';
import 'package:datingapp/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuth extends AuthController {
  bool signedOutCalled = false;

  @override
  AuthState build() => AuthState.authenticated;

  @override
  Future<void> signedOut() async => signedOutCalled = true;
}

class _FakeSafetyRepo implements SafetyRepository {
  _FakeSafetyRepo(this._load);

  final Future<List<BlockedUser>> Function() _load;
  final unblocked = <int>[];
  int loads = 0;

  @override
  Future<List<BlockedUser>> getBlockedUsers() {
    loads++;
    return _load();
  }

  @override
  Future<void> unblock(int userId) async => unblocked.add(userId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The screen at '/settings' inside a router that also knows the destinations
/// it links to, so navigation can be observed.
Widget _settingsApp(_FakeAuth auth) {
  Widget page(String label) => Scaffold(body: Text(label));
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/', builder: (context, state) => page('welcome page')),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/preferences',
        builder: (context, state) => page('preferences page'),
      ),
      GoRoute(
        path: '/settings/blocked-users',
        builder: (context, state) => page('blocked page'),
      ),
      GoRoute(
        path: '/settings/subscription',
        builder: (context, state) => page('subscription page'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => auth)],
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
}

Future<void> _pumpSettings(WidgetTester tester, _FakeAuth auth) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_settingsApp(auth));
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsScreen', () {
    testWidgets('lists every section and row from the design', (tester) async {
      await _pumpSettings(tester, _FakeAuth());

      for (final text in [
        'Settings',
        'Account',
        'Profile preferences',
        'Notifications',
        'Privacy & safety',
        'Blocked users',
        'Subscription',
        'Support',
        'Help & support',
        'Legal',
        'About Elcarino',
        'Log out',
        'Delete account',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });

    testWidgets('unbuilt rows say "Soon" and tell you so when tapped', (
      tester,
    ) async {
      await _pumpSettings(tester, _FakeAuth());

      // Account, Notifications, Help & support, Legal, Delete account.
      expect(find.text('Soon'), findsNWidgets(5));

      await tester.tap(find.text('Notifications'));
      await tester.pump();
      expect(find.text('Coming soon.'), findsOneWidget);
    });

    for (final (row, page) in [
      ('Profile preferences', 'preferences page'),
      ('Blocked users', 'blocked page'),
      ('Subscription', 'subscription page'),
    ]) {
      testWidgets('the "$row" row opens its screen', (tester) async {
        await _pumpSettings(tester, _FakeAuth());

        await tester.tap(find.text(row).last);
        await tester.pumpAndSettle();

        expect(find.text(page), findsOneWidget);
      });
    }

    testWidgets('About shows the app name and the licences button', (
      tester,
    ) async {
      await _pumpSettings(tester, _FakeAuth());

      await tester.tap(find.text('About Elcarino'));
      await tester.pumpAndSettle();

      expect(find.text('Meaningful connections, safely.'), findsOneWidget);
      expect(find.text('View licenses'), findsOneWidget);
    });

    testWidgets('Log out asks first; cancelling keeps you signed in', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await _pumpSettings(tester, auth);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(auth.signedOutCalled, isFalse);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('confirming Log out signs out and returns to the start', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await _pumpSettings(tester, auth);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      // The dialog's own confirm button (the row behind it is also "Log out").
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Log out'),
        ),
      );
      await tester.pumpAndSettle();

      expect(auth.signedOutCalled, isTrue);
      expect(find.text('welcome page'), findsOneWidget);
    });
  });

  group('BlockedUsersScreen', () {
    Widget app(_FakeSafetyRepo repo) => ProviderScope(
      overrides: [safetyRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BlockedUsersScreen(),
      ),
    );

    testWidgets('lists blocked people, falling back for a deactivated one', (
      tester,
    ) async {
      final repo = _FakeSafetyRepo(
        () async => const [
          BlockedUser(id: 1, displayName: 'Jordan', photo: null),
          BlockedUser(id: 2, displayName: null, photo: null),
        ],
      );
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();

      expect(find.text('Jordan'), findsOneWidget);
      expect(find.text('Deactivated user'), findsOneWidget);
      // The compact button lays out inside a row (no unbounded-width error).
      expect(find.text('Unblock'), findsNWidgets(2));
    });

    testWidgets('Unblock removes that person', (tester) async {
      final repo = _FakeSafetyRepo(
        () async => const [
          BlockedUser(id: 1, displayName: 'Jordan', photo: null),
          BlockedUser(id: 2, displayName: 'Riley', photo: null),
        ],
      );
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unblock').first);
      await tester.pumpAndSettle();

      expect(repo.unblocked, [1]);
      expect(find.text('Jordan'), findsNothing);
      expect(find.text('Riley'), findsOneWidget);
    });

    testWidgets('an empty list explains itself', (tester) async {
      await tester.pumpWidget(app(_FakeSafetyRepo(() async => [])));
      await tester.pumpAndSettle();

      expect(find.text('No blocked users'), findsOneWidget);
    });

    testWidgets('an error shows Retry', (tester) async {
      var attempt = 0;
      final repo = _FakeSafetyRepo(() async {
        attempt++;
        if (attempt == 1) {
          throw ApiException(
            code: 'server_error',
            message: 'Server unavailable',
            statusCode: 500,
          );
        }
        return const [BlockedUser(id: 1, displayName: 'Jordan', photo: null)];
      });
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.text('Server unavailable'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Jordan'), findsOneWidget);
      expect(repo.loads, 2);
    });
  });
}
