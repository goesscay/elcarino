import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../data/chat_repository.dart';
import '../domain/icebreakers.dart';

/// Tappable opening lines for a conversation that has no messages yet
/// (Phase 4, open decision #25), shown under "You matched!".
///
/// A tap **fills the composer, it does not send**: the line is a starting point
/// the person can change, and nothing goes out in their voice without their
/// tap on Send. `More ideas` asks for a fresh set (the server avoids repeating
/// the last one and rate-limits it).
///
/// Purely a nicety, so it's best-effort and silent: while loading, or if the
/// request fails, it takes no space at all rather than showing an error the
/// person can do nothing about. Only a failed *refresh* speaks up, since they
/// asked for it.
class IcebreakerSuggestions extends ConsumerStatefulWidget {
  const IcebreakerSuggestions({
    required this.conversationId,
    required this.onPick,
    super.key,
  });

  final int conversationId;

  /// Called with the chosen line; the parent puts it in the composer.
  final ValueChanged<String> onPick;

  @override
  ConsumerState<IcebreakerSuggestions> createState() =>
      _IcebreakerSuggestionsState();
}

class _IcebreakerSuggestionsState extends ConsumerState<IcebreakerSuggestions> {
  IcebreakerSet? _set;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final set = await ref
          .read(chatRepositoryProvider)
          .getIcebreakers(widget.conversationId);
      if (mounted) setState(() => _set = set);
    } on ApiException {
      // Best-effort: no suggestions is fine.
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final set = await ref
          .read(chatRepositoryProvider)
          .refreshIcebreakers(widget.conversationId);
      if (mounted) setState(() => _set = set);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final set = _set;
    if (set == null || set.lines.isEmpty) return const SizedBox.shrink();

    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Ideas to start the chat', style: text.labelLarge),
              if (set.isAi) ...[
                const SizedBox(width: AppSpacing.sm),
                _AiLabel(color: p.textSecondary),
              ],
              const Spacer(),
              TextButton(
                onPressed: _refreshing ? null : _refresh,
                child: const Text('More ideas'),
              ),
            ],
          ),
          for (final line in set.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _IcebreakerCard(
                line: line,
                onTap: () => widget.onPick(line),
              ),
            ),
        ],
      ),
    );
  }
}

class _IcebreakerCard extends StatelessWidget {
  const _IcebreakerCard({required this.line, required this.onTap});

  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'Use this opening line: $line',
      excludeSemantics: true,
      child: Material(
        color: p.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.north_west_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small "AI" tag, shown only when a model wrote the lines.
class _AiLabel extends StatelessWidget {
  const _AiLabel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Written by AI',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Text(
            'AI',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}
