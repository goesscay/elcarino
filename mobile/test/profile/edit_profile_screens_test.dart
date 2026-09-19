import 'package:datingapp/core/theme/app_theme.dart';
import 'package:datingapp/core/widgets/section_row.dart';
import 'package:datingapp/onboarding/presentation/photos_screen.dart';
import 'package:datingapp/profile/data/profile_repository.dart';
import 'package:datingapp/profile/domain/gender.dart';
import 'package:datingapp/profile/domain/interest.dart';
import 'package:datingapp/profile/domain/profile.dart';
import 'package:datingapp/profile/presentation/edit_basics_screen.dart';
import 'package:datingapp/profile/presentation/edit_interests_screen.dart';
import 'package:datingapp/profile/presentation/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeRepo implements ProfileRepository {
  _FakeRepo({this.profile, this.catalogue = const [], this.mine = const []});

  Profile? profile;
  final List<Interest> catalogue;
  final List<Interest> mine;

  final deleted = <int>[];
  final reorders = <List<int>>[];
  List<int>? savedInterests;
  ({String name, Gender gender, String? bio})? savedBasics;

  @override
  Future<Profile?> getProfile() async => profile;

  @override
  Future<void> deletePhoto(int photoId) async => deleted.add(photoId);

  @override
  Future<void> reorderPhotos(List<int> orderedIds) async =>
      reorders.add(orderedIds);

  @override
  Future<List<Interest>> getInterestCatalogue() async => catalogue;

  @override
  Future<List<Interest>> getMyInterests() async => mine;

  @override
  Future<List<Interest>> updateInterests(List<int> interestIds) async {
    savedInterests = interestIds;
    return catalogue.where((i) => interestIds.contains(i.id)).toList();
  }

  @override
  Future<Profile> updateProfileBasics({
    required String displayName,
    required DateTime birthDate,
    required Gender gender,
    String? bio,
    String? relationshipGoal,
    String? religion,
    String? politics,
  }) async {
    savedBasics = (name: displayName, gender: gender, bio: bio);
    return profile!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Profile _profile({List<ProfilePhoto> photos = const []}) => Profile(
  id: 1,
  displayName: 'Sam',
  birthDate: DateTime(2000, 9, 17),
  gender: Gender.man,
  bio: 'Hello there',
  relationshipGoal: null,
  religion: null,
  politics: null,
  isVerified: false,
  completionPct: 80,
  photos: photos,
);

ProfilePhoto _photo(int id, {String status = 'approved'}) => ProfilePhoto(
  id: id,
  url: 'http://localhost/p$id.jpg',
  sortOrder: id,
  moderationStatus: status,
);

/// The screen sits on top of a base route so `Navigator.pop` (Save, Continue)
/// has somewhere to return to, inside a real router for `context.push`.
Widget _app(Widget screen, {_FakeRepo? repo}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/screen'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(path: '/screen', builder: (context, state) => screen),
      GoRoute(
        path: '/profile/edit/photos',
        builder: (context, state) => const Scaffold(body: Text('photos page')),
      ),
      GoRoute(
        path: '/profile/edit/basics',
        builder: (context, state) => const Scaffold(body: Text('basics page')),
      ),
      GoRoute(
        path: '/profile/edit/interests',
        builder: (context, state) =>
            const Scaffold(body: Text('interests page')),
      ),
      GoRoute(
        path: '/profile/edit/prompts',
        builder: (context, state) => const Scaffold(body: Text('prompts page')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      if (repo != null) profileRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
}

Future<void> _openScreen(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('SectionCard / SectionRow', () {
    testWidgets('renders rows with subtitles and reports taps', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SectionCard(
              children: [
                SectionRow(
                  icon: Icons.person_outline,
                  title: 'Basics',
                  subtitle: 'Name and more',
                  onTap: () => tapped++,
                ),
                SectionRow(
                  icon: Icons.delete_outline,
                  title: 'Delete account',
                  destructive: true,
                  showChevron: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Basics'), findsOneWidget);
      expect(find.text('Name and more'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.tap(find.text('Basics'));
      expect(tapped, 1);
    });
  });

  group('EditProfileScreen', () {
    testWidgets('lists the four sections and each opens its editor', (
      tester,
    ) async {
      await _openScreen(tester, _app(const EditProfileScreen()));

      for (final title in ['Photos', 'Basics & bio', 'Interests', 'Prompts']) {
        expect(find.text(title), findsOneWidget);
      }
      await tester.tap(find.text('Basics & bio'));
      await tester.pumpAndSettle();
      expect(find.text('basics page'), findsOneWidget);
    });
  });

  group('PhotosScreen', () {
    testWidgets('first photo is "Main"; only the next empty slot invites', (
      tester,
    ) async {
      final repo = _FakeRepo(profile: _profile(photos: [_photo(1), _photo(2)]));
      await _openScreen(
        tester,
        _app(const PhotosScreen(step: null), repo: repo),
      );

      expect(find.byType(ProfilePhotoTile), findsNWidgets(2));
      expect(find.text('Main'), findsOneWidget);
      // 6 slots, 2 filled -> 4 empty, one of them the labelled invitation.
      expect(find.byType(AddPhotoTile), findsNWidgets(4));
      expect(find.text('Add photo'), findsOneWidget);
    });

    testWidgets('a photo still in moderation is flagged "In review"', (
      tester,
    ) async {
      final repo = _FakeRepo(
        profile: _profile(
          photos: [
            _photo(1),
            _photo(2, status: 'pending'),
          ],
        ),
      );
      await _openScreen(
        tester,
        _app(const PhotosScreen(step: null), repo: repo),
      );

      expect(find.text('In review'), findsOneWidget);
    });

    testWidgets('removing a photo asks first, then deletes it', (tester) async {
      final repo = _FakeRepo(profile: _profile(photos: [_photo(1), _photo(2)]));
      await _openScreen(
        tester,
        _app(const PhotosScreen(step: null), repo: repo),
      );

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Remove this photo?'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(repo.deleted, [1]);
      expect(find.byType(ProfilePhotoTile), findsOneWidget);
    });

    testWidgets('cancelling the remove dialog deletes nothing', (tester) async {
      final repo = _FakeRepo(profile: _profile(photos: [_photo(1)]));
      await _openScreen(
        tester,
        _app(const PhotosScreen(step: null), repo: repo),
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.deleted, isEmpty);
      expect(find.byType(ProfilePhotoTile), findsOneWidget);
    });

    testWidgets('moving a photo later persists the new order', (tester) async {
      final repo = _FakeRepo(
        profile: _profile(photos: [_photo(1), _photo(2), _photo(3)]),
      );
      await _openScreen(
        tester,
        _app(const PhotosScreen(step: null), repo: repo),
      );

      // The first tile's "move later" (chevron right).
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.reorders, [
        [2, 1, 3],
      ]);
    });

    testWidgets(
      'the first photo cannot move earlier, the last cannot move later',
      (tester) async {
        final repo = _FakeRepo(
          profile: _profile(photos: [_photo(1), _photo(2)]),
        );
        await _openScreen(
          tester,
          _app(const PhotosScreen(step: null), repo: repo),
        );

        await tester.tap(
          find.byIcon(Icons.chevron_left_rounded).first,
        ); // tile 1
        await tester.tap(
          find.byIcon(Icons.chevron_right_rounded).last,
        ); // tile 2
        await tester.pumpAndSettle();

        expect(repo.reorders, isEmpty);
      },
    );

    testWidgets(
      'Continue is disabled with no photos, and calls onDone otherwise',
      (tester) async {
        var done = 0;

        final empty = _FakeRepo(profile: _profile());
        await _openScreen(
          tester,
          _app(
            PhotosScreen(
              step: null,
              continueLabel: 'Done',
              onDone: () => done++,
            ),
            repo: empty,
          ),
        );
        await tester.tap(find.text('Done'));
        expect(done, 0);

        final filled = _FakeRepo(profile: _profile(photos: [_photo(1)]));
        await _openScreen(
          tester,
          _app(
            PhotosScreen(
              step: null,
              continueLabel: 'Done',
              onDone: () => done++,
            ),
            repo: filled,
          ),
        );
        await tester.tap(find.text('Done'));
        expect(done, 1);
      },
    );
  });

  group('EditBasicsScreen', () {
    testWidgets('groups fields under headings and loads the profile', (
      tester,
    ) async {
      final repo = _FakeRepo(profile: _profile());
      await _openScreen(tester, _app(const EditBasicsScreen(), repo: repo));

      for (final heading in [
        'Basic information',
        'About me',
        'Relationship goal',
        'Optional',
      ]) {
        expect(find.text(heading), findsOneWidget);
      }
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Hello there'), findsOneWidget);
    });

    testWidgets('choosing a gender chip changes what gets saved', (
      tester,
    ) async {
      final repo = _FakeRepo(profile: _profile());
      await _openScreen(tester, _app(const EditBasicsScreen(), repo: repo));

      await tester.tap(find.text('Woman'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.savedBasics?.gender, Gender.woman);
      expect(repo.savedBasics?.name, 'Sam');
    });

    testWidgets('an empty name blocks saving', (tester) async {
      final repo = _FakeRepo(profile: _profile());
      await _openScreen(tester, _app(const EditBasicsScreen(), repo: repo));

      await tester.enterText(find.widgetWithText(TextFormField, 'Sam'), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.savedBasics, isNull);
      expect(find.text('Enter your name'), findsOneWidget);
    });
  });

  group('EditInterestsScreen', () {
    const catalogue = [
      Interest(id: 1, name: 'Hiking', category: 'Outdoors'),
      Interest(id: 2, name: 'Running', category: 'Outdoors'),
      Interest(id: 3, name: 'Live music', category: 'Culture'),
    ];

    testWidgets('groups by category and reflects the current selection', (
      tester,
    ) async {
      final repo = _FakeRepo(
        catalogue: catalogue,
        mine: const [Interest(id: 1, name: 'Hiking', category: 'Outdoors')],
      );
      await _openScreen(tester, _app(const EditInterestsScreen(), repo: repo));

      expect(find.text('Outdoors'), findsOneWidget);
      expect(find.text('Culture'), findsOneWidget);
      expect(find.text('Save (1 selected)'), findsOneWidget);
    });

    testWidgets('toggling chips updates the count and saves the ids', (
      tester,
    ) async {
      final repo = _FakeRepo(catalogue: catalogue);
      await _openScreen(tester, _app(const EditInterestsScreen(), repo: repo));

      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Running'));
      await tester.tap(find.text('Live music'));
      await tester.pump();
      expect(find.text('Save (2 selected)'), findsOneWidget);

      await tester.tap(find.text('Save (2 selected)'));
      await tester.pumpAndSettle();

      expect(repo.savedInterests?.toSet(), {2, 3});
    });
  });
}
