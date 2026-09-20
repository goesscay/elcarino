import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/profile/data/profile_repository.dart';
import 'package:datingapp/profile/domain/gender.dart';
import 'package:datingapp/profile/domain/interest.dart';
import 'package:datingapp/profile/domain/profile.dart';
import 'package:datingapp/profile/domain/prompt.dart';
import 'package:datingapp/profile/presentation/my_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile({
  bool verified = false,
  String? bio = 'Weekend hiker.',
  int completion = 80,
}) => Profile(
  id: 1,
  displayName: 'Sam',
  birthDate: DateTime(2000, 9, 17),
  gender: Gender.man,
  bio: bio,
  relationshipGoal: null,
  religion: null,
  politics: null,
  isVerified: verified,
  completionPct: completion,
  photos: const [], // no network in tests — placeholder renders
);

const _interests = [
  Interest(id: 1, name: 'Hiking', category: null),
  Interest(id: 2, name: 'Live music', category: null),
];

const _prompts = [
  AnsweredPrompt(
    promptId: 1,
    promptText: 'A perfect Sunday is…',
    answer: 'Coffee, a long walk, and no plans.',
  ),
];

Widget _view(
  Profile profile, {
  List<Interest> interests = const [],
  List<AnsweredPrompt> prompts = const [],
  VoidCallback? onEditProfile,
  VoidCallback? onEditPreferences,
  VoidCallback? onVerify,
  ThemeData? theme,
}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(
    body: ProfileView(
      profile: profile,
      interests: interests,
      prompts: prompts,
      onEditProfile: onEditProfile ?? () {},
      onEditPreferences: onEditPreferences ?? () {},
      onVerify: onVerify,
    ),
  ),
);

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({required this.profile, this.interests, this.prompts});

  final Future<Profile?> Function() profile;
  final Future<List<Interest>> Function()? interests;
  final Future<List<AnsweredPrompt>> Function()? prompts;
  int profileCalls = 0;

  @override
  Future<Profile?> getProfile() {
    profileCalls++;
    return profile();
  }

  @override
  Future<List<Interest>> getMyInterests() =>
      interests?.call() ?? Future.value(const []);

  @override
  Future<List<AnsweredPrompt>> getMyPrompts() =>
      prompts?.call() ?? Future.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _screen(_FakeProfileRepository repo) => ProviderScope(
  overrides: [profileRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(theme: AppTheme.light, home: const MyProfileScreen()),
);

/// A tall surface so every section of the (lazy) ListView is built.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('ProfileView', () {
    testWidgets('shows name, age, completeness and both edit actions', (
      tester,
    ) async {
      _tall(tester);
      var editedProfile = 0;
      var editedPrefs = 0;
      await tester.pumpWidget(
        _view(
          _profile(),
          onEditProfile: () => editedProfile++,
          onEditPreferences: () => editedPrefs++,
        ),
      );

      final age = ageFromBirthDate(DateTime(2000, 9, 17));
      expect(find.text('Sam, $age'), findsOneWidget);
      expect(find.text('Profile completeness'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);

      await tester.tap(find.text('Edit profile'));
      await tester.tap(find.text('Edit preferences'));
      expect(editedProfile, 1);
      expect(editedPrefs, 1);
    });

    testWidgets('verification: pill text and avatar badge follow the flag', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(_view(_profile(verified: false)));
      expect(find.text('Not verified'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsNothing);

      await tester.pumpWidget(_view(_profile(verified: true)));
      expect(find.text('Verified'), findsOneWidget);
      // One in the pill, one badge on the avatar.
      expect(find.byIcon(Icons.verified), findsNWidgets(2));
    });

    testWidgets('renders bio, interests and prompts when present', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _view(_profile(), interests: _interests, prompts: _prompts),
      );

      expect(find.text('About me'), findsOneWidget);
      expect(find.text('Weekend hiker.'), findsOneWidget);
      expect(find.text('Interests'), findsOneWidget);
      expect(find.text('Hiking'), findsOneWidget);
      expect(find.text('Live music'), findsOneWidget);
      expect(find.text('Prompts'), findsOneWidget);
      expect(find.text('A perfect Sunday is…'), findsOneWidget);
      expect(find.text('Coffee, a long walk, and no plans.'), findsOneWidget);
    });

    testWidgets('omits empty sections instead of showing empty headings', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(_view(_profile(bio: null)));

      expect(find.text('About me'), findsNothing);
      expect(find.text('Interests'), findsNothing);
      expect(find.text('Prompts'), findsNothing);
    });

    testWidgets('renders in the dark theme', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _view(_profile(), interests: _interests, theme: AppTheme.dark),
      );
      expect(find.text('Edit profile'), findsOneWidget);
    });
  });

  group('MyProfileScreen loading', () {
    testWidgets('loads and shows the profile with its interests', (
      tester,
    ) async {
      _tall(tester);
      final repo = _FakeProfileRepository(
        profile: () async => _profile(),
        interests: () async => _interests,
      );
      await tester.pumpWidget(_screen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Hiking'), findsOneWidget);
    });

    testWidgets('a failing interests/prompts read does not break the screen', (
      tester,
    ) async {
      _tall(tester);
      final repo = _FakeProfileRepository(
        profile: () async => _profile(),
        interests: () async => throw Exception('boom'),
        prompts: () async => throw Exception('boom'),
      );
      await tester.pumpWidget(_screen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Interests'), findsNothing);
    });

    testWidgets('a profile error shows a message and Retry reloads', (
      tester,
    ) async {
      _tall(tester);
      var attempt = 0;
      final repo = _FakeProfileRepository(
        profile: () async {
          attempt++;
          if (attempt == 1) {
            throw Exception('down');
          }
          return _profile();
        },
      );
      await tester.pumpWidget(_screen(repo));
      await tester.pumpAndSettle();

      expect(find.text('Could not load your profile.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Edit profile'), findsOneWidget);
      expect(repo.profileCalls, 2);
    });

    testWidgets('no profile yet shows guidance', (tester) async {
      _tall(tester);
      final repo = _FakeProfileRepository(profile: () async => null);
      await tester.pumpWidget(_screen(repo));
      await tester.pumpAndSettle();

      expect(find.text('No profile yet'), findsOneWidget);
    });
  });

  group('ageFromBirthDate', () {
    final now = DateTime(2026, 9, 19);

    test('birthday already passed this year', () {
      expect(ageFromBirthDate(DateTime(2000, 9, 18), now: now), 26);
    });

    test('birthday is today', () {
      expect(ageFromBirthDate(DateTime(2000, 9, 19), now: now), 26);
    });

    test('birthday still to come this year', () {
      expect(ageFromBirthDate(DateTime(2000, 9, 20), now: now), 25);
    });
  });
  group('Get verified card', () {
    testWidgets('an unverified profile is offered verification', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(_view(_profile(), onVerify: () => opened++));

      expect(find.text('Get verified'), findsOneWidget);
      await tester.tap(find.text('Get verified'));

      expect(opened, 1);
    });

    testWidgets('a verified profile is not', (tester) async {
      await tester.pumpWidget(_view(_profile(verified: true), onVerify: () {}));

      expect(find.text('Get verified'), findsNothing);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('no card without a way to open the flow', (tester) async {
      await tester.pumpWidget(_view(_profile()));

      expect(find.text('Get verified'), findsNothing);
    });
  });
}
