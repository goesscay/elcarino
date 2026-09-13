import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';

/// Phase 0 placeholder, still standing in for the main-tab shell (Discover /
/// Matches / Likes / Profile — a real bottom-nav shell isn't built yet).
/// Links to the three real destinations that exist post-onboarding: Discover
/// (item 5/6), Matches (item 6), and My profile (item 3). Deleted once
/// there's a proper tab bar to replace it.
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
                onPressed: () => context.push('/discover'),
                child: const Text('Discover'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => context.push('/matches'),
                child: const Text('Matches'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
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
