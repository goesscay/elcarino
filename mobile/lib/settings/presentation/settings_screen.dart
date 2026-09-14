import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_spacing.dart';

/// docs/07-ui-ux-design.md's nav map: Settings -> Account, Notifications,
/// Privacy & Safety (-> Blocked users), Subscription, Help & Support, Legal,
/// Log out, Delete account. `MyProfileScreen`'s gear icon showed
/// "Settings — coming soon" until this feature and Push notifications
/// (item 9) both landed — its own doc comment said as much.
///
/// **Privacy & Safety -> Blocked users**, **Subscription** (Phase 2 item 1 —
/// was coming-soon until this feature landed), and **Log out** are real
/// here. Notifications (per-type toggles need a preferences table that
/// doesn't exist), Help & Support / Legal (static content, a Phase 0 gap
/// already flagged), and Delete account (the `DELETE /account` endpoint
/// exists, docs/03, but its confirmation UX is its own scope) still show a
/// coming-soon notice instead of a dead navigation — same pattern as the
/// Google/Apple sign-in buttons. Log out itself was a real, silent gap
/// before Phase 1 item 10: `AuthController.signedOut()` existed but nothing
/// in the app ever called it outside of an automatic session-loss redirect.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _comingSoon(BuildContext context) async {
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
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(authControllerProvider.notifier).signedOut();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          children: [
            const _SectionHeader('Account'),
            ListTile(
              title: const Text('Account'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _comingSoon(context),
            ),
            ListTile(
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _comingSoon(context),
            ),
            const Divider(),
            const _SectionHeader('Privacy & Safety'),
            ListTile(
              title: const Text('Blocked users'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/blocked-users'),
            ),
            const Divider(),
            const _SectionHeader('Subscription'),
            ListTile(
              title: const Text('Subscription'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/subscription'),
            ),
            const Divider(),
            const _SectionHeader('Support'),
            ListTile(
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _comingSoon(context),
            ),
            ListTile(
              title: const Text('Legal'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _comingSoon(context),
            ),
            const Divider(),
            ListTile(
              title: const Text('Log out'),
              onTap: () => _logOut(context, ref),
            ),
            ListTile(
              title: const Text(
                'Delete account',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _comingSoon(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
