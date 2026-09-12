import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/domain/auth_intent.dart';
import '../../authentication/presentation/auth_method_screen.dart';
import '../../authentication/presentation/email_entry_screen.dart';
import '../../authentication/presentation/otp_screen.dart';
import '../../authentication/presentation/phone_entry_screen.dart';
import '../../authentication/presentation/welcome_screen.dart';
import '../../onboarding/presentation/location_permission_screen.dart';
import '../../onboarding/presentation/notification_permission_screen.dart';
import '../../onboarding/presentation/onboarding_complete_screen.dart';
import '../../onboarding/presentation/photos_screen.dart';
import '../../onboarding/presentation/preferences_screen.dart';
import '../../onboarding/presentation/profile_basics_screen.dart';
import '../../onboarding/presentation/prompts_screen.dart';
import '../../placeholder_home.dart';
import '../../profile/presentation/edit_basics_screen.dart';
import '../../profile/presentation/edit_interests_screen.dart';
import '../../profile/presentation/edit_profile_screen.dart';
import '../../profile/presentation/my_profile_screen.dart';
import '../widgets/splash_screen.dart';

/// App router, per the navigation map in `docs/07-ui-ux-design.md` §2.2:
/// Splash -> (not authed) Welcome -> Auth method -> Email/Phone -> OTP ->
/// Onboarding wizard -> Main tabs. [SplashScreen] does the routing decision
/// (auth state, then the onboarding step) rather than a `redirect` callback —
/// simpler to reason about, and this app has no automatic session-loss event
/// yet that would need a global redirect to react to.
///
/// Main tabs (Discover/Matches/Likes/Profile) don't exist yet — `/home` is
/// still the Phase 0 placeholder until Discovery (Phase 1 item 5) lands.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/home', builder: (context, state) => const PlaceholderHome()),

      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(
        path: '/auth/method',
        builder: (context, state) => AuthMethodScreen(intent: state.extra! as AuthIntent),
      ),
      GoRoute(path: '/auth/phone', builder: (context, state) => const PhoneEntryScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => OtpScreen(phone: state.extra! as String),
      ),
      GoRoute(
        path: '/auth/email',
        builder: (context, state) => EmailEntryScreen(intent: state.extra! as AuthIntent),
      ),

      GoRoute(path: '/onboarding/basics', builder: (context, state) => const ProfileBasicsScreen()),
      GoRoute(path: '/onboarding/photos', builder: (context, state) => const PhotosScreen()),
      GoRoute(path: '/onboarding/prompts', builder: (context, state) => const PromptsScreen()),
      GoRoute(
        path: '/onboarding/preferences',
        builder: (context, state) => const PreferencesScreen(),
      ),
      GoRoute(
        path: '/onboarding/location',
        builder: (context, state) => const LocationPermissionScreen(),
      ),
      GoRoute(
        path: '/onboarding/notifications',
        builder: (context, state) => const NotificationPermissionScreen(),
      ),
      GoRoute(
        path: '/onboarding/complete',
        builder: (context, state) => const OnboardingCompleteScreen(),
      ),

      // Profile module (Phase 1 item 3). Photos/Prompts/Preferences are the
      // same screens the onboarding wizard uses, reused here with a "Done"
      // button that pops back instead of advancing the wizard, and no
      // progress bar (step: null) since there's no wizard to show progress
      // through outside onboarding.
      GoRoute(path: '/profile', builder: (context, state) => const MyProfileScreen()),
      GoRoute(path: '/profile/edit', builder: (context, state) => const EditProfileScreen()),
      GoRoute(
        path: '/profile/edit/basics',
        builder: (context, state) => const EditBasicsScreen(),
      ),
      GoRoute(
        path: '/profile/edit/interests',
        builder: (context, state) => const EditInterestsScreen(),
      ),
      GoRoute(
        path: '/profile/edit/photos',
        builder: (context, state) => PhotosScreen(
          step: null,
          continueLabel: 'Done',
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
      GoRoute(
        path: '/profile/edit/prompts',
        builder: (context, state) => PromptsScreen(
          step: null,
          continueLabel: 'Done',
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
      GoRoute(
        path: '/profile/preferences',
        builder: (context, state) => PreferencesScreen(
          step: null,
          continueLabel: 'Done',
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
    ],
  );
});
