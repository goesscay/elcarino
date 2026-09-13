import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/onboarding/data/onboarding_gate.dart';
import 'package:datingapp/onboarding/domain/onboarding_step.dart';
import 'package:datingapp/profile/data/profile_repository.dart';
import 'package:datingapp/profile/domain/gender.dart';
import 'package:datingapp/profile/domain/preferences.dart';
import 'package:datingapp/profile/domain/profile.dart';
import 'package:datingapp/profile/domain/prompt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_token_storage.dart';

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository({
    this.profile,
    this.prompts = const [],
    this.preferences,
  }) : super(ApiClient(tokenStorage: FakeTokenStorage()));

  final Profile? profile;
  final List<AnsweredPrompt> prompts;
  final Preferences? preferences;

  @override
  Future<Profile?> getProfile() async => profile;

  @override
  Future<List<AnsweredPrompt>> getMyPrompts() async => prompts;

  @override
  Future<Preferences?> getPreferences() async => preferences;
}

Profile _profileWithPhotos(List<ProfilePhoto> photos) => Profile(
  id: 1,
  displayName: 'Jane',
  birthDate: DateTime(1995, 1, 1),
  gender: Gender.woman,
  bio: null,
  relationshipGoal: null,
  isVerified: false,
  completionPct: 40,
  photos: photos,
);

const _somePhoto = ProfilePhoto(
  id: 1,
  url: 'https://x.test/1.jpg',
  sortOrder: 0,
  moderationStatus: 'pending',
);

const _somePreferences = Preferences(
  minAge: 18,
  maxAge: 40,
  maxDistanceKm: 50,
  interestedInGenders: [Gender.woman],
);

void main() {
  group('OnboardingGate.resolveNextStep (docs/07 §3.1 wizard order)', () {
    test('no profile yet -> basics', () async {
      final gate = OnboardingGate(_FakeProfileRepository());
      expect(await gate.resolveNextStep(), OnboardingStep.basics);
    });

    test('profile but no photos -> photos', () async {
      final gate = OnboardingGate(
        _FakeProfileRepository(profile: _profileWithPhotos([])),
      );
      expect(await gate.resolveNextStep(), OnboardingStep.photos);
    });

    test('photos but no answered prompts -> prompts', () async {
      final gate = OnboardingGate(
        _FakeProfileRepository(profile: _profileWithPhotos([_somePhoto])),
      );
      expect(await gate.resolveNextStep(), OnboardingStep.prompts);
    });

    test('prompts but no preferences -> preferences', () async {
      final gate = OnboardingGate(
        _FakeProfileRepository(
          profile: _profileWithPhotos([_somePhoto]),
          prompts: const [
            AnsweredPrompt(promptId: 1, promptText: 'x', answer: 'y'),
          ],
        ),
      );
      expect(await gate.resolveNextStep(), OnboardingStep.preferences);
    });

    test('everything present -> complete', () async {
      final gate = OnboardingGate(
        _FakeProfileRepository(
          profile: _profileWithPhotos([_somePhoto]),
          prompts: const [
            AnsweredPrompt(promptId: 1, promptText: 'x', answer: 'y'),
          ],
          preferences: _somePreferences,
        ),
      );
      expect(await gate.resolveNextStep(), OnboardingStep.complete);
    });
  });
}
