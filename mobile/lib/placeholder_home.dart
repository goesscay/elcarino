import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';

/// Phase 0 placeholder, still standing in for the main-tab shell (Discover /
/// Matches / Likes / Profile — Phase 1 items 5-7 haven't landed yet). Now
/// links to the one real destination that exists post-onboarding: My profile
/// (Phase 1 item 3). Deleted once Discovery gives the app a real first tab.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.current;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Elcarino',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Phase 0 scaffold — env: ${config.environment.name}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                config.apiBaseUrl,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => context.push('/profile'),
                child: const Text('My profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
