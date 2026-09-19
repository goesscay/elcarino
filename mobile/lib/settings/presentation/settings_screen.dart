import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/section_row.dart';

/// docs/07-ui-ux-design.md's nav map: Settings -> Account, Notifications,
/// Privacy & Safety (-> Blocked users), Subscription, Help & Support, Legal,
/// Log out, Delete account. `MyProfileScreen`'s gear icon showed
/// "Settings — coming soon" until this feature and Push notifications
/// (item 9) both landed — its own doc comment said as much.
///
/// **Real here:** Profile preferences (the existing Edit preferences screen),
/// Privacy & Safety -> Blocked users, Subscription (Phase 2 item 1), About
/// (a small dialog — wordmark, tagline, and Flutter's built-in open-source
/// licences page), and Log out. Notifications (per-type toggles need a
/// preferences table that doesn't exist), Account, Help & Support / Legal
/// (static content, a Phase 0 gap already flagged), and Delete account (the
/// `DELETE /account` endpoint exists, docs/03, but its confirmation UX is its
/// own scope) show a "Soon" label and a coming-soon notice rather than a dead
/// navigation — same pattern as the Google/Apple sign-in buttons. Log out
/// itself was a real, silent gap before Phase 1 item 10:
/// `AuthController.signedOut()` existed but nothing in the app ever called it
/// outside of an automatic session-loss redirect.
///
/// Log out and Delete account sit apart, at the bottom, in their own card.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Coming soon.')));
  }

  Future<void> _logOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(authControllerProvider.notifier).signedOut();
    if (context.mounted) context.go('/');
  }

  /// A small About dialog: the wordmark, the tagline, and a link to Flutter's
  /// built-in open-source licences page (which app stores expect to exist).
  /// No version line: reading it needs a platform plugin this app doesn't
  /// otherwise depend on.
  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(width: 160),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Meaningful connections, safely.',
              textAlign: TextAlign.center,
              style: Theme.of(dialogContext).textTheme.bodyMedium
                  ?.copyWith(color: dialogContext.palette.textSecondary),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              showLicensePage(context: context, applicationName: 'Elcarino');
            },
            child: const Text('View licenses'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        toolbarHeight: 64,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            const _GroupTitle('Account'),
            SectionCard(
              children: [
                SectionRow(
                  icon: Icons.person_outline,
                  title: 'Account',
                  trailingLabel: 'Soon',
                  onTap: () => _comingSoon(context),
                ),
                SectionRow(
                  icon: Icons.tune_rounded,
                  title: 'Profile preferences',
                  subtitle: 'Who you see: age, distance, interested in',
                  onTap: () => context.push('/profile/preferences'),
                ),
                SectionRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  trailingLabel: 'Soon',
                  onTap: () => _comingSoon(context),
                ),
              ],
            ),
            const _GroupTitle('Privacy & safety'),
            SectionCard(
              children: [
                SectionRow(
                  icon: Icons.block_rounded,
                  title: 'Blocked users',
                  onTap: () => context.push('/settings/blocked-users'),
                ),
              ],
            ),
            const _GroupTitle('Subscription'),
            SectionCard(
              children: [
                SectionRow(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Subscription',
                  onTap: () => context.push('/settings/subscription'),
                ),
              ],
            ),
            const _GroupTitle('Support'),
            SectionCard(
              children: [
                SectionRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & support',
                  trailingLabel: 'Soon',
                  onTap: () => _comingSoon(context),
                ),
                SectionRow(
                  icon: Icons.description_outlined,
                  title: 'Legal',
                  trailingLabel: 'Soon',
                  onTap: () => _comingSoon(context),
                ),
                SectionRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About Elcarino',
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            SectionCard(
              children: [
                SectionRow(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  showChevron: false,
                  onTap: () => _logOut(context, ref),
                ),
                SectionRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete account',
                  destructive: true,
                  showChevron: false,
                  trailingLabel: 'Soon',
                  onTap: () => _comingSoon(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: context.palette.textSecondary),
      ),
    );
  }
}
