import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The app's one "nothing here / something went wrong" block: a soft icon
/// circle, a message, and an optional action. Every empty and error state uses
/// this so they read as a family — purposeful copy plus a next step, never a
/// blank page (docs/07 §5).
class StateMessage extends StatelessWidget {
  const StateMessage({
    required this.icon,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.celebratory = false,
    super.key,
  });

  final IconData icon;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A good-news state (verified, matched...): the icon sits on the brand tint
  /// in brand red instead of the usual quiet grey.
  final bool celebratory;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: celebratory ? p.primaryTint : p.fill,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Icon(
                    icon,
                    size: 36,
                    color: celebratory ? AppColors.primary : p.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: title == null
                    ? text.bodyLarge
                    : text.bodyMedium?.copyWith(color: p.textSecondary),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
