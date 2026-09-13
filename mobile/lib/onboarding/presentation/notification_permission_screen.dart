import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_spacing.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Notification permission": "Rationale -> OS
/// prompt. Denial is fine; app continues." No device-token registration here
/// on purpose — `POST /users/me/devices` belongs to Push notifications
/// (Phase 1 item 9), which doesn't exist yet (docs/04 item 2's deferred
/// list). This only requests the OS permission.
class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen> {
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    await Permission.notification.request();
    if (!mounted) return;
    context.go('/onboarding/complete');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Notifications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.notifications_outlined, size: 64),
          const SizedBox(height: AppSpacing.md),
          const Text(
            "We'll let you know about new matches, messages, and likes — nothing else.",
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton(
            onPressed: _requesting ? null : _request,
            child: const Text('Enable notifications'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _requesting
                ? null
                : () => context.go('/onboarding/complete'),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }
}
