import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_spacing.dart';
import '../../discovery/data/discovery_repository.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Location permission": "Rationale screen ->
/// OS prompt. Fallback: manual city/region picker if denied."
///
/// Now that PUT /users/me/location exists (Phase 1 item 5), this screen
/// actually captures and sends a position, not just the OS permission
/// prompt. Per docs/06-security-architecture.md §4 ("the app must degrade
/// gracefully, not block"), any failure here — permission denied, GPS
/// unavailable, a network hiccup — is swallowed and onboarding continues
/// regardless; Discovery will simply 422 with `location_required` later if
/// it's ever reached without a location set. The manual city/region fallback
/// for a denial still isn't built (no geocoding in scope) — flagged, not
/// silently dropped.
///
/// `getCurrentPosition` is bounded with a client-side `.timeout(...)` —
/// confirmed live (emulator with location services enabled but no fused/
/// network fix ever resolving) that without one this hangs indefinitely,
/// and worse, since the "Not now" button is also disabled while a request
/// is in flight, that stranded the user on this step with no way forward.
/// A bounded timeout is swallowed by the same catch below, same as any
/// other failure here.
class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends ConsumerState<LocationPermissionScreen> {
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);

    try {
      final status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
          ),
        ).timeout(const Duration(seconds: 8));
        await ref
            .read(discoveryRepositoryProvider)
            .updateLocation(
              latitude: position.latitude,
              longitude: position.longitude,
            );
      }
    } catch (_) {
      // Swallowed on purpose — see class doc. Nothing to show the user; this
      // step is soft by design, same as the notification-permission screen.
    }

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
            child: _requesting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Allow location access'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _requesting
                ? null
                : () => context.go('/onboarding/notifications'),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }
}
