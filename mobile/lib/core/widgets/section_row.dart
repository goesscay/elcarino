import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A rounded, hairline-bordered card holding a vertical stack of
/// [SectionRow]s, separated by dividers inset to line up with the row text.
/// The one "grouped list" primitive: Edit profile's sections and Settings both
/// build on it, so lists of navigation rows look the same everywhere.
class SectionCard extends StatelessWidget {
  const SectionCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(indent: SectionRow.textIndent),
          ],
        ],
      ),
    );
  }
}

/// One tappable row: an icon in a soft circle, a title, an optional one-line
/// description, and a chevron. [destructive] tints it with the danger colour
/// (Delete account, Log out), which is how those stay visually separate.
class SectionRow extends StatelessWidget {
  const SectionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    this.showChevron = true,
    this.trailingLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  /// Short text shown in place of the chevron (e.g. "Soon") for a row that
  /// isn't available yet.
  final String? trailingLabel;

  /// Where the title text starts (padding + icon circle + gap) — the divider
  /// insets to here.
  static const textIndent = AppSpacing.lg + _iconCircle + AppSpacing.md;
  static const _iconCircle = 40.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final accent = destructive ? AppColors.danger : AppColors.primary;
    final titleColor = destructive ? AppColors.danger : p.textPrimary;

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: subtitle == null ? title : '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: destructive
                      ? AppColors.danger.withValues(alpha: 0.12)
                      : p.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: _iconCircle,
                  height: _iconCircle,
                  child: Icon(icon, size: 20, color: accent),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(color: titleColor),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: text.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailingLabel != null)
                Text(trailingLabel!, style: text.bodySmall)
              else if (showChevron)
                Icon(Icons.chevron_right_rounded, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small section heading for a form or list ("Basic information", "About
/// me"). Consistent spacing so form screens read as labelled groups.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.label, {this.hint, super.key});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.headlineSmall),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
