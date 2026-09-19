import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/network_photo.dart';
import '../../matching/domain/swipe_direction.dart';
import '../../matching/presentation/swipe_flow.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/block_confirm_dialog.dart';
import '../domain/candidate.dart';

/// docs/07 §3.2 "Profile detail": another person's profile, opened from a Likes
/// tile (and, next, from Explore). It only *renders* a [DiscoveryCandidate] the
/// list already fetched, so it needs no API of its own — and, on purpose, no
/// "GET any user's profile" endpoint that could be walked to scrape people.
///
/// One vertical scroll: the main photo, who they are, bio and interests, then
/// their remaining photos interleaved with their prompt answers (a prompt, a
/// photo, a prompt, ...) — the "carousel interleaved with prompt answers" of
/// the spec, as a scroll rather than a swipe so each answer gets room.
///
/// When [canRespond] is true a pinned footer offers **Pass** and **Like**
/// through the same [submitSwipe] as the Discover deck (a mutual like plays the
/// match celebration). The screen pops with `true` once the person has been
/// dealt with — answered, or blocked — so the list underneath can drop them.
/// The overflow menu carries Report and Block (docs/07 §1: reachable in two
/// taps from any profile).
class CandidateDetailScreen extends ConsumerStatefulWidget {
  const CandidateDetailScreen({
    required this.candidate,
    this.canRespond = true,
    super.key,
  });

  final DiscoveryCandidate candidate;
  final bool canRespond;

  @override
  ConsumerState<CandidateDetailScreen> createState() =>
      _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends ConsumerState<CandidateDetailScreen> {
  bool _busy = false;

  DiscoveryCandidate get _candidate => widget.candidate;

  Future<void> _respond(SwipeDirection direction) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await submitSwipe(
      context: context,
      ref: ref,
      candidate: _candidate,
      direction: direction,
    );
    if (!mounted) return;
    if (ok) {
      context.pop(true);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _report() => context.push(
    '/safety/report',
    extra: (_candidate.id, _candidate.displayName),
  );

  Future<void> _block() async {
    final confirmed = await showBlockConfirmDialog(
      context,
      _candidate.displayName,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(safetyRepositoryProvider).block(_candidate.id);
      if (mounted) context.pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _candidate;
    final photos = candidate.photos;
    final prompts = candidate.prompts;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: photos.isEmpty
                    ? const PhotoPlaceholder()
                    : NetworkPhoto(photos.first.url),
              ),
              _Info(candidate: candidate),
              // Prompt, photo, prompt, photo ... until both run out.
              for (var i = 0; i < _interleaveCount(photos.length, prompts); i++)
                ..._interleaved(context, i),
              SizedBox(height: widget.canRespond ? AppSpacing.xl : 40),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  _RoundControl(
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  _MoreMenu(onReport: _report, onBlock: _block),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.canRespond
          ? _Footer(
              busy: _busy,
              onPass: () => _respond(SwipeDirection.left),
              onLike: () => _respond(SwipeDirection.right),
            )
          : null,
    );
  }

  /// How many (prompt, photo) pairs to lay out: photos after the first, or the
  /// prompts, whichever is more — so nothing is dropped.
  int _interleaveCount(int photoCount, List<Object?> prompts) {
    final extraPhotos = photoCount > 1 ? photoCount - 1 : 0;
    return extraPhotos > prompts.length ? extraPhotos : prompts.length;
  }

  List<Widget> _interleaved(BuildContext context, int i) {
    final photos = _candidate.photos;
    final prompts = _candidate.prompts;
    return [
      if (i < prompts.length)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            0,
          ),
          child: _PromptCard(
            prompt: prompts[i].promptText,
            answer: prompts[i].answer,
          ),
        ),
      if (i + 1 < photos.length)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            0,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: NetworkPhoto(photos[i + 1].url),
            ),
          ),
        ),
    ];
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.candidate});

  final DiscoveryCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final bio = candidate.bio;
    final goal = candidate.relationshipGoal;
    final distance = candidate.distanceLabel;
    final shared = candidate.sharedInterests.toSet();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.xl,
        AppSpacing.screen,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  '${candidate.displayName}, ${candidate.age}',
                  style: text.headlineMedium,
                ),
              ),
              if (candidate.isVerified) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.verified,
                  color: AppColors.primary,
                  size: 22,
                  semanticLabel: 'Verified',
                ),
              ],
            ],
          ),
          if (distance != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: p.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(distance, style: text.bodySmall),
              ],
            ),
          ],
          if (goal != null && goal.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Chip(
              avatar: const Icon(
                Icons.favorite_border_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(goal),
            ),
          ],
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(bio, style: text.bodyLarge),
          ],
          if (candidate.interests.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Interests', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final name in candidate.interests)
                  _InterestChip(name: name, shared: shared.contains(name)),
              ],
            ),
            if (shared.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Highlighted: you have ${shared.length} in common.',
                style: text.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// A shared interest is picked out in the brand tint, the rest sit in a plain
/// fill — same "one accent, used sparingly" rule as the rest of the app.
class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.name, required this.shared});

  final String name;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: shared ? p.primaryTint : p.fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          name,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: shared ? AppColors.primary : p.textPrimary),
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt, required this.answer});

  final String prompt;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt.isNotEmpty) Text(prompt, style: text.bodySmall),
            if (prompt.isNotEmpty) const SizedBox(height: AppSpacing.sm),
            Text(answer, style: text.titleLarge),
          ],
        ),
      ),
    );
  }
}

/// A small translucent circle that stays legible over any photo.
class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.photoControl,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppColors.onPhoto, size: 22),
          ),
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.onReport, required this.onBlock});

  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: (value) => value == 'report' ? onReport() : onBlock(),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'report', child: Text('Report')),
        PopupMenuItem(value: 'block', child: Text('Block')),
      ],
      child: const IgnorePointer(
        child: SizedBox(
          width: 44,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.photoControl,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.more_horiz_rounded,
              color: AppColors.onPhoto,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.busy,
    required this.onPass,
    required this.onLike,
  });

  final bool busy;
  final VoidCallback onPass;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onPass,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Pass'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onLike,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  // A match celebration can take a moment to arrive; show it's
                  // working rather than a button that's just gone grey.
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_rounded),
                  label: const Text('Like'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
