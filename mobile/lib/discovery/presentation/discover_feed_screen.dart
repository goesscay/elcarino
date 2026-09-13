import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../../matching/data/matching_repository.dart';
import '../../matching/domain/swipe_direction.dart';
import '../../matching/presentation/match_celebration_dialog.dart';
import '../../matching/presentation/swipeable_card.dart';
import '../data/discovery_repository.dart';
import '../domain/candidate.dart';

/// docs/07-ui-ux-design.md §3.2 "Card stack" — now that Phase 1 item 6
/// (POST /swipes) exists, this replaced item 5's plain paginated list with
/// the real swipe-gesture stack. Boost icon [PROPOSED] isn't shown — it's a
/// Phase 2 mechanic with nothing behind it yet; the filter icon reuses the
/// existing Edit preferences screen rather than a second, parallel filters
/// UI.
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

  @override
  void initState() {
    super.initState();
    _load();
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
    });

    try {
      final result = await ref
          .read(matchingRepositoryProvider)
          .swipe(targetId: candidate.id, direction: direction);
      if (result.matched && mounted) {
        await showMatchCelebration(context, candidate);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
            onPressed: () =>
                context.push('/profile/preferences').then((_) => _load()),
          ),
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
      return _Guidance(
        icon: Icons.location_off_outlined,
        message: 'Turn on location to see people nearby.',
        actionLabel: 'Set location',
        onAction: () =>
            context.push('/onboarding/location').then((_) => _load()),
      );
    }

    if (_errorCode == 'preferences_required') {
      return _Guidance(
        icon: Icons.tune,
        message: 'Set your discovery preferences to get started.',
        actionLabel: 'Set preferences',
        onAction: () =>
            context.push('/profile/preferences').then((_) => _load()),
      );
    }

    if (_errorCode != null) {
      return _Guidance(
        icon: Icons.error_outline,
        message: _errorMessage ?? 'Something went wrong.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_candidates.isEmpty) {
      return _Guidance(
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
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Stack(
              children: [
                // A non-interactive card peeking out behind the top one, for
                // visual depth only — never receives gestures.
                if (_candidates.length > 1)
                  Positioned.fill(
                    top: 8,
                    child: Transform.scale(
                      scale: 0.96,
                      child: IgnorePointer(child: _peek(_candidates[1])),
                    ),
                  ),
                Positioned.fill(
                  child: SwipeableCard(
                    key: ValueKey(_candidates.first.id),
                    candidate: _candidates.first,
                    onSwiped: (direction) => _performSwipe(direction),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.close,
                color: Colors.red,
                onPressed: _swiping
                    ? null
                    : () => _performSwipe(SwipeDirection.left),
              ),
              _ActionButton(
                icon: Icons.favorite,
                color: Colors.green,
                onPressed: _swiping
                    ? null
                    : () => _performSwipe(SwipeDirection.right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _peek(DiscoveryCandidate candidate) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: candidate.photos.isEmpty
          ? Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            )
          : Image.network(
              candidate.photos.first.url,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon, color: color, size: 32),
        padding: const EdgeInsets.all(AppSpacing.lg),
        onPressed: onPressed,
      ),
    );
  }
}

class _Guidance extends StatelessWidget {
  const _Guidance({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
