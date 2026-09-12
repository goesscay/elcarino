import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/profile_repository.dart';
import '../domain/onboarding_step.dart';

/// Decides which onboarding step an authenticated user should land on —
/// resolved from the API's own data, not a client-side flag, so a resumed
/// session (app killed mid-onboarding, reinstalled, new device) picks up in
/// the right place: docs/07-ui-ux-design.md §3.1's wizard is
/// "basics -> photos -> prompts -> preferences -> location -> notifications".
///
/// Known limitation, documented rather than silently assumed away: the
/// location/notification-permission steps and "onboarding complete" persist
/// nothing server-side (there's no backend field for it — see
/// docs/04-development-phases.md item 2's deferred list), so they only ever
/// run once, in one linear pass, right after preferences are saved. If the
/// app is killed between "preferences saved" and "onboarding complete", a
/// resumed session sees preferences already exist and resolves straight to
/// `complete`, skipping the two permission screens on that resume. Revisit if
/// that gap matters enough to warrant a real backend flag.
class OnboardingGate {
  OnboardingGate(this._profiles);

  final ProfileRepository _profiles;

  Future<OnboardingStep> resolveNextStep() async {
    final profile = await _profiles.getProfile();
    if (profile == null) return OnboardingStep.basics;
    if (profile.photos.isEmpty) return OnboardingStep.photos;

    final prompts = await _profiles.getMyPrompts();
    if (prompts.isEmpty) return OnboardingStep.prompts;

    final preferences = await _profiles.getPreferences();
    if (preferences == null) return OnboardingStep.preferences;

    return OnboardingStep.complete;
  }
}

final onboardingGateProvider = Provider<OnboardingGate>(
  (ref) => OnboardingGate(ref.watch(profileRepositoryProvider)),
);
