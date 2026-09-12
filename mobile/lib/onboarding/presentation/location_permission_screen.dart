import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_spacing.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Location permission": "Rationale screen ->
/// OS prompt. Fallback: manual city/region picker if denied."
///
/// No backend call here on purpose — there's no location-submitting endpoint
/// yet (docs/04-development-phases.md item 2's deferred list: it belongs with
/// Discovery, item 5, which is what actually reads `user_locations`). This
/// screen only requests the OS permission; the manual city/region fallback
/// for a denial isn't built either, for the same reason — nowhere to send it
/// yet. Revisit both once Discovery lands.
class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    await Permission.locationWhenInUse.request();
    if (!mounted) return;
    context.go('/onboarding/notifications');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Location',
      step: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.location_on_outlined, size: 64),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Elcarino uses your location to show you people nearby. We only ever '
            'share an approximate distance — never your exact location.',
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton(
            onPressed: _requesting ? null : _request,
            child: const Text('Allow location access'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _requesting ? null : () => context.go('/onboarding/notifications'),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }
}
