import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../chat/data/chat_repository.dart';
import '../../chat/domain/conversation.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/state_message.dart';
import '../../matching/data/matching_repository.dart';
import '../../matching/domain/swipe_direction.dart';
import '../../matching/presentation/match_celebration_dialog.dart';
import '../../matching/presentation/swipeable_card.dart';
import '../../profile/data/profile_repository.dart';
import '../data/discovery_repository.dart';
import '../domain/boost_status.dart';
import '../domain/candidate.dart';

/// docs/07-ui-ux-design.md §3.2 "Card stack" — now that Phase 1 item 6
/// (POST /swipes) exists, this replaced item 5's plain paginated list with
/// the real swipe-gesture stack. The filter icon reuses the existing Edit
/// preferences screen rather than a second, parallel filters UI. The boost
/// icon [PROPOSED] now opens a bottom sheet (Phase 2 item 3) rather than
/// docs/07's more elaborate dedicated paywall-modal treatment for the
/// free-user case — a disclosed simplification, same one PremiumScreen's
/// own doc comment already uses elsewhere in this phase.
class DiscoverFeedScreen extends ConsumerStatefulWidget {
  const DiscoverFeedScreen({super.key});

  @override
  ConsumerState<DiscoverFeedScreen> createState() => _DiscoverFeedScreenState();
}

class _DiscoverFeedScreenState extends ConsumerState<DiscoverFeedScreen> {
  bool _loading = true;
  bool _loadingMore = false;
  bool _swiping = false;
  String? _errorCode;
  String? _errorMessage;
  List<DiscoveryCandidate> _candidates = [];
  bool _hasMore = false;
  int _page = 1;

  /// How far the top card has been dragged toward committing (0 -> 1); the
  /// card behind it grows into place as this rises.
  final _dragProgress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dragProgress.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorCode = null;
    });
    try {
      final result = await ref.read(discoveryRepositoryProvider).getFeed();
      if (!mounted) return;
      setState(() {
        _page = 1;
        _candidates = result.candidates;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCode = e.code;
        _errorMessage = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _maybeLoadMore() async {
    if (_loadingMore || !_hasMore || _candidates.length > 2) return;
    setState(() => _loadingMore = true);
    try {
      final result = await ref
          .read(discoveryRepositoryProvider)
          .getFeed(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page += 1;
        _candidates = [..._candidates, ...result.candidates];
        _hasMore = result.hasMore;
      });
    } on ApiException catch (_) {
      // Running low on cards is a soft-fail case — just stop trying to top
      // up; the empty state below handles "nothing left" gracefully.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _performSwipe(SwipeDirection direction) async {
    if (_swiping || _candidates.isEmpty) return;
    final candidate = _candidates.first;

    setState(() {
      _swiping = true;
      _candidates = _candidates.skip(1).toList();
      _dragProgress.value = 0;
    });

    try {
      final result = await ref
          .read(matchingRepositoryProvider)
          .swipe(targetId: candidate.id, direction: direction);
      if (result.matched && mounted) {
        // The chat to open and the viewer's own photo (for the two-photo
        // celebration) are independent reads — fetch them together.
        final (conversation, myPhotoUrl) = await (
          _findConversation(result.matchId),
          _findMyPhotoUrl(),
        ).wait;
        if (!mounted) return;
        await showMatchCelebration(
          context,
          candidate,
          conversation: conversation,
          myPhotoUrl: myPhotoUrl,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _swiping = false);
    }

    unawaited(_maybeLoadMore());
  }

  /// `SwipeService` (item 6) creates a `Conversation` alongside every
  /// `UserMatch` in the same request, so it's already there to look up by
  /// the time the swipe response comes back — no extra wait, just an extra
  /// `GET /chat/conversations` round-trip so the celebration dialog's "Send
  /// a message" button has somewhere real to go.
  Future<Conversation?> _findConversation(int? matchId) async {
    if (matchId == null) return null;
    try {
      final conversations = await ref
          .read(chatRepositoryProvider)
          .getConversations();
      for (final conversation in conversations) {
        if (conversation.matchId == matchId) return conversation;
      }
      return null;
    } on ApiException {
      return null;
    }
  }

  /// The viewer's own primary photo, for the match celebration. Best-effort:
  /// a failure just means the celebration shows a placeholder for it rather
  /// than delaying or blocking the moment.
  Future<String?> _findMyPhotoUrl() async {
    try {
      final profile = await ref.read(profileRepositoryProvider).getProfile();
      final photos = profile?.photos ?? const [];
      return photos.isEmpty ? null : photos.first.url;
    } on ApiException {
      return null;
    }
  }

  Future<void> _openBoost() async {
    await showModalBottomSheet<void>(
      context: context,
      // Over the tab bar, not clipped above it.
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetContext) => _BoostSheet(
        onActivated: () {
          if (mounted) _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The wordmark stands in for a "Discover" title: the tab bar already
        // says where you are, and the logo is what a dating app's home leads
        // with.
        title: const Padding(
          padding: EdgeInsets.only(left: AppSpacing.xs),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppLogo(width: 112),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
            onPressed: () =>
                context.push('/profile/preferences').then((_) => _load()),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorCode == 'location_required') {
      return StateMessage(
        icon: Icons.location_off_outlined,
        message: 'Turn on location to see people nearby.',
        actionLabel: 'Set location',
        onAction: () =>
            context.push('/onboarding/location').then((_) => _load()),
      );
    }

    if (_errorCode == 'preferences_required') {
      return StateMessage(
        icon: Icons.tune,
        message: 'Set your discovery preferences to get started.',
        actionLabel: 'Set preferences',
        onAction: () =>
            context.push('/profile/preferences').then((_) => _load()),
      );
    }

    if (_errorCode != null) {
      return StateMessage(
        icon: Icons.error_outline,
        message: _errorMessage ?? 'Something went wrong.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_candidates.isEmpty) {
      return StateMessage(
        icon: Icons.search_off,
        message: 'No one new nearby right now. Check back later, or widen your preferences.',
        actionLabel: 'Refresh',
        onAction: _load,
      );
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              0,
            ),
            child: Stack(
              children: [
                // A non-interactive card peeking out behind the top one, for
                // depth only - never receives gestures. It grows to full size
                // as the top card is dragged away.
                if (_candidates.length > 1)
                  Positioned.fill(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _dragProgress,
                      builder: (context, progress, child) => Transform.scale(
                        scale: 0.94 + 0.06 * progress,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                      child: IgnorePointer(
                        child: SwipePeekCard(candidate: _candidates[1]),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: SwipeableCard(
                    key: ValueKey(_candidates.first.id),
                    candidate: _candidates.first,
                    dragProgress: _dragProgress,
                    onSwiped: (direction) => _performSwipe(direction),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ActionButton(
                icon: Icons.close_rounded,
                label: 'Pass',
                size: 60,
                iconColor: AppColors.pass,
                onPressed: _swiping
                    ? null
                    : () => _performSwipe(SwipeDirection.left),
              ),
              const SizedBox(width: AppSpacing.xl),
              _ActionButton(
                icon: Icons.favorite_rounded,
                label: 'Like',
                size: 72,
                filled: true,
                onPressed: _swiping
                    ? null
                    : () => _performSwipe(SwipeDirection.right),
              ),
              const SizedBox(width: AppSpacing.xl),
              _ActionButton(
                icon: Icons.bolt_rounded,
                label: 'Boost',
                size: 60,
                iconColor: AppColors.primary,
                onPressed: _openBoost,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A circular action under the card. [filled] is the one primary action (Like:
/// solid brand red); the rest are quiet white circles with a hairline.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.size,
    required this.onPressed,
    this.filled = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final double size;
  final bool filled;
  final Color? iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: filled ? AppColors.primary : p.surface,
          shape: CircleBorder(
            side: filled ? BorderSide.none : BorderSide(color: p.border),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: size * 0.46,
                color: filled ? AppColors.onPrimary : iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Phase 2 item 3. A bottom sheet rather than docs/07's more elaborate
/// generic paywall-modal concept for the non-subscriber case — same
/// disclosed simplification PremiumScreen and the advanced-filters lock
/// (item 2) already use.
class _BoostSheet extends ConsumerStatefulWidget {
  const _BoostSheet({required this.onActivated});

  final VoidCallback onActivated;

  @override
  ConsumerState<_BoostSheet> createState() => _BoostSheetState();
}

class _BoostSheetState extends ConsumerState<_BoostSheet> {
  bool _loading = true;
  bool _activating = false;
  String? _error;
  BoostStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await ref
          .read(discoveryRepositoryProvider)
          .getBoostStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _activate() async {
    setState(() => _activating = true);
    try {
      await ref.read(discoveryRepositoryProvider).activateBoost();
      if (!mounted) return;
      widget.onActivated();
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _activating = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final status = _status;
    if (status == null || _error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.palette.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Icon(
                Icons.bolt_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Boost',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _statusMessage(status),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!status.isEntitled)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/settings/subscription');
            },
            child: const Text('Upgrade to Premium'),
          )
        else if (status.canActivateAnother)
          FilledButton(
            onPressed: _activating ? null : _activate,
            child: _activating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Activate boost'),
          ),
      ],
    );
  }

  String _statusMessage(BoostStatus status) {
    if (status.active) {
      // .toLocal(): the backend sends an ISO 8601 UTC timestamp
      // (DateTime.parse keeps it flagged as UTC, so .hour/.minute without
      // this would show the UTC hour, not the device's) — caught live on
      // the emulator (a device clock away from UTC), not by a test, since
      // the repository-level test fixtures didn't exercise a non-UTC
      // device timezone.
      final ends = status.endsAt!.toLocal();
      final time =
          '${ends.hour.toString().padLeft(2, '0')}:${ends.minute.toString().padLeft(2, '0')}';
      return "You're boosted until $time.";
    }
    if (!status.isEntitled) {
      return 'Get priority placement in the discovery feed with Premium.';
    }
    if (!status.canActivateAnother) {
      return "You've used all your boosts for this month.";
    }
    return 'You have ${status.limit! - status.usedThisMonth} of ${status.limit} '
        'boosts left this month.';
  }
}
