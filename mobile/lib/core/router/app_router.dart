import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/domain/auth_intent.dart';
import '../../authentication/presentation/auth_method_screen.dart';
import '../../authentication/presentation/email_entry_screen.dart';
import '../../authentication/presentation/otp_screen.dart';
import '../../authentication/presentation/phone_entry_screen.dart';
import '../../authentication/presentation/welcome_screen.dart';
import '../../calls/domain/call.dart';
import '../../calls/domain/call_type.dart';
import '../../calls/presentation/call_screen.dart';
import '../../chat/domain/conversation.dart';
import '../../chat/presentation/conversation_loader_screen.dart';
import '../../chat/presentation/conversation_screen.dart';
import '../../chat/presentation/inbox_screen.dart';
import '../../discovery/presentation/discover_feed_screen.dart';
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
import '../../profile/presentation/edit_prompts_screen.dart';
import '../../profile/presentation/my_profile_screen.dart';
import '../../safety/presentation/blocked_users_screen.dart';
import '../../safety/presentation/report_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../subscriptions/presentation/premium_screen.dart';
import '../widgets/splash_screen.dart';

/// App router, per the navigation map in `docs/07-ui-ux-design.md` §2.2:
/// Splash -> (not authed) Welcome -> Auth method -> Email/Phone -> OTP ->
/// Onboarding wizard -> Main tabs. [SplashScreen] does the routing decision
/// (auth state, then the onboarding step) rather than a `redirect` callback —
/// simpler to reason about, and this app has no automatic session-loss event
/// yet that would need a global redirect to react to.
///
/// Main tabs (Discover/Matches/Likes/Profile) as a real bottom-nav shell
/// don't exist yet — `/home` is still the Phase 0 placeholder, now linking to
/// both `/discover` (item 5) and `/profile` (item 3) as separate pushed
/// routes rather than tabs.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const PlaceholderHome(),
      ),
      GoRoute(
        path: '/discover',
        builder: (context, state) => const DiscoverFeedScreen(),
      ),
      GoRoute(
        path: '/matches',
        builder: (context, state) => const InboxScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        // `extra` carries the already-loaded Conversation for in-app
        // navigation (InboxScreen, the match-celebration dialog). A tapped
        // push notification (Phase 1 item 9) only has the id, so falls
        // through to ConversationLoaderScreen, which fetches it.
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Conversation) {
            return ConversationScreen(conversation: extra);
          }
          return ConversationLoaderScreen(
            conversationId: int.parse(state.pathParameters['id']!),
          );
        },
      ),

      // Phase 3 items 4/5 (open decisions #19/#20, confirmed WebRTC).
      // `extra` is a (Conversation, CallType, Call?) record — the third
      // element is non-null only when routed here as the callee answering
      // an already-incoming call (see CallScreen's own doc comment).
      GoRoute(
        path: '/calls',
        builder: (context, state) {
          final (conversation, type, incomingCall) =
              state.extra! as (Conversation, CallType, Call?);
          return CallScreen(
            conversation: conversation,
            type: type,
            incomingCall: incomingCall,
          );
        },
      ),

      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth/method',
        builder: (context, state) =>
            AuthMethodScreen(intent: state.extra! as AuthIntent),
      ),
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => OtpScreen(phone: state.extra! as String),
      ),
      GoRoute(
        path: '/auth/email',
        builder: (context, state) =>
            EmailEntryScreen(intent: state.extra! as AuthIntent),
      ),

      GoRoute(
        path: '/onboarding/basics',
        builder: (context, state) => const ProfileBasicsScreen(),
      ),
      GoRoute(
        path: '/onboarding/photos',
        builder: (context, state) => const PhotosScreen(),
      ),
      GoRoute(
        path: '/onboarding/prompts',
        builder: (context, state) => const PromptsScreen(),
      ),
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

      // Profile module (Phase 1 item 3). Photos/Preferences are the same
      // screens the onboarding wizard uses, reused here with a "Done" button
      // that pops back instead of advancing the wizard, and no progress bar
      // (step: null) since there's no wizard to show progress through
      // outside onboarding. Edit prompts (item 4) is its own screen —
      // docs/07 §3.5 describes it differently from onboarding's picker
      // (reorder/swap/edit an already-answered set, not "pick 3 from
      // scratch") — see edit_prompts_screen.dart.
      GoRoute(
        path: '/profile',
        builder: (context, state) => const MyProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
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
        builder: (context, state) => const EditPromptsScreen(),
      ),
      GoRoute(
        path: '/profile/preferences',
        builder: (context, state) => PreferencesScreen(
          step: null,
          continueLabel: 'Done',
          onDone: () => Navigator.of(context).pop(),
        ),
      ),

      // Settings (Phase 1 item 10) — only Privacy & Safety -> Blocked users
      // and Log out are real, see SettingsScreen's own doc comment.
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/blocked-users',
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      // Phase 2 item 1 — was "coming soon" (Phase 1 item 10).
      GoRoute(
        path: '/settings/subscription',
        builder: (context, state) => const PremiumScreen(),
      ),
      // `extra` is a (userId, displayName) record — from ConversationScreen's
      // header overflow, the only entry point into reporting someone today.
      GoRoute(
        path: '/safety/report',
        builder: (context, state) {
          final (userId, displayName) = state.extra! as (int, String);
          return ReportScreen(userId: userId, displayName: displayName);
        },
      ),
    ],
  );
});
