import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_spacing.dart';
import '../../notifications/data/push_repository.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Notification permission": "Rationale -> OS
/// prompt. Denial is fine; app continues." Now that Push notifications
/// (Phase 1 item 9) exists, this also registers the FCM token —
/// [PushRepository.registerCurrentDevice] no-ops entirely if no Firebase
/// project is configured for this build, so nothing here needs to know or
/// care whether that's the case.
class NotificationPermissionScreen extends ConsumerStatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  ConsumerState<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends ConsumerState<NotificationPermissionScreen> {
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    final status = await Permission.notification.request();
    if (status.isGranted) {
      await ref.read(pushRepositoryProvider).registerCurrentDevice();
    }
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
