import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/tab_refresh.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/state_message.dart';
import '../../discovery/domain/candidate.dart';
import '../../discovery/presentation/person_tile.dart';
import '../data/likes_repository.dart';
import '../domain/likes_page.dart';

/// docs/07 §3.4 "Likes": two tabs — **People who like you** (premium) and
/// **People you like** (free).
///
/// For a non-subscriber the first tab is a paywall over a *count*: the server
/// sends how many people like them and nothing else (no ids, no photos), so
/// what's blurred behind the prompt is decoration, not real people. A
/// subscriber sees a grid; tapping a tile opens the profile detail with Like /
/// Pass, and a person leaves the grid once answered.
class LikesScreen extends ConsumerStatefulWidget {
  const LikesScreen({super.key});

  @override
  ConsumerState<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends ConsumerState<LikesScreen> {
  int _tab = 0;

  /// How many people like the viewer, for the header badge. Reported by the
  /// "who liked me" list whenever it loads.
  int _receivedTotal = 0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Row(
          children: [
            Text('Likes', style: text.headlineMedium),
            if (_receivedTotal > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              _CountBadge(_receivedTotal),
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _LikesTabs(
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              // Both lists stay alive so switching tabs is instant and keeps
              // each one's scroll position.
              child: IndexedStack(
                index: _tab,
                children: [
                  _LikesList(
                    mode: LikesMode.received,
                    onTotal: (total) {
                      if (total != _receivedTotal) {
                        setState(() => _receivedTotal = total);
                      }
                    },
                  ),
                  const _LikesList(mode: LikesMode.sent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum LikesMode { received, sent }

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count new',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.onPrimary, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

/// The two-tab switcher: text with a brand-red underline on the selected one,
/// over a hairline.
class _LikesTabs extends StatelessWidget {
  const _LikesTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  static const _labels = ['People who like you', 'People you like'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: _labels[i],
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 2,
                          color: i == selected
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Text(
                      _labels[i],
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 14,
                        color: i == selected
                            ? AppColors.primary
                            : p.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LikesList extends ConsumerStatefulWidget {
  const _LikesList({required this.mode, this.onTotal});

  final LikesMode mode;
  final ValueChanged<int>? onTotal;

  @override
  ConsumerState<_LikesList> createState() => _LikesListState();
}

class _LikesListState extends ConsumerState<_LikesList> {
  final _scroll = ScrollController();

  bool _loading = true;

  /// Whether a load has ever succeeded, so a reload of an empty or locked list
  /// keeps showing it rather than flashing a spinner.
  bool _loaded = false;
  bool _loadingMore = false;
  String? _error;
  List<DiscoveryCandidate> _likes = [];
  int _total = 0;
  bool _locked = false;
  bool _hasMore = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _load();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  Future<LikesPage> _fetch(int page) {
    final repository = ref.read(likesRepositoryProvider);
    return widget.mode == LikesMode.received
        ? repository.getReceived(page: page)
        : repository.getSent(page: page);
  }

  Future<void> _load() async {
    // Stale-while-revalidate: a reload keeps what's on screen and swaps it in.
    setState(() {
      _loading = !_loaded;
      _error = null;
    });
    try {
      final page = await _fetch(1);
      if (!mounted) return;
      setState(() {
        _likes = page.likes;
        _total = page.total;
        _locked = page.locked;
        _hasMore = page.hasMore;
        _page = 1;
        _loading = false;
        _loaded = true;
      });
      widget.onTotal?.call(page.total);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients || _loadingMore || !_hasMore) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _page += 1;
        _likes = [..._likes, ...page.likes];
        _hasMore = page.hasMore;
      });
    } on ApiException {
      // Soft-fail: stop topping up; what's loaded stays usable.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(DiscoveryCandidate candidate) async {
    final dealtWith = await context.push<bool>(
      '/profile/candidate',
      extra: (candidate, widget.mode == LikesMode.received),
    );
    if (dealtWith == true && mounted) {
      setState(() {
        _likes = _likes.where((c) => c.id != candidate.id).toList();
        _total = _total > 0 ? _total - 1 : 0;
      });
      widget.onTotal?.call(_total);
    }
  }

  Future<void> _upgrade() async {
    await context.push('/settings/subscription');
    // They may have subscribed while there.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    // Reload when the Likes tab is (re)selected, so a like that arrived while
    // on another tab is here when you come back.
    ref.listen(likesTabRefreshProvider, (previous, next) => _load());

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && !_loaded) {
      return StateMessage(
        icon: Icons.error_outline,
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_total == 0 && _likes.isEmpty) {
      return widget.mode == LikesMode.received
          ? const StateMessage(
              icon: Icons.favorite_border_rounded,
              title: 'No likes yet',
              message: "When someone likes you, they'll show up here.",
            )
          : StateMessage(
              icon: Icons.favorite_border_rounded,
              title: 'Nothing waiting',
              message:
                  "People you've liked who haven't answered yet will show up "
                  'here.',
              actionLabel: 'Keep discovering',
              onAction: () => context.go('/discover'),
            );
    }

    if (_locked) {
      return RefreshIndicator(
        onRefresh: _load,
        child: _LockedLikes(total: _total, onUpgrade: _upgrade),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screen),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.78,
        ),
        itemCount: _likes.length,
        itemBuilder: (context, index) => PersonTile(
          candidate: _likes[index],
          onTap: () => _open(_likes[index]),
        ),
      ),
    );
  }
}

/// The free-user state of "People who like you": how many, a blurred mosaic of
/// *placeholder* tiles (the server sent no people), and the upgrade prompt.
class _LockedLikes extends StatelessWidget {
  const _LockedLikes({required this.total, required this.onUpgrade});

  final int total;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final tiles = total.clamp(1, 4);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Text(
          total == 1 ? '1 person likes you' : '$total people like you',
          style: text.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.profileCard),
          child: SizedBox(
            height: 340,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: _Mosaic(count: tiles),
                ),
                ColoredBox(color: p.surface.withValues(alpha: 0.4)),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.border),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Upgrade to see who likes you',
                          textAlign: TextAlign.center,
                          style: text.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton(
                          onPressed: onUpgrade,
                          child: const Text('See who likes you'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Decoration behind the paywall: [count] flat placeholder tiles (one, two, or a
/// 2x2 for three or more) that always fill the card. They stand in for people
/// the server deliberately didn't send.
class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget tile(int i) => ColoredBox(
      color: i.isEven ? p.primaryTint : p.fill,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: count == 1 ? 180 : 110,
          color: AppColors.primary.withValues(alpha: 0.45),
        ),
      ),
    );

    if (count == 1) return SizedBox.expand(child: tile(0));
    Widget row(int a, int b) => Expanded(
      child: Row(
        children: [
          Expanded(child: SizedBox.expand(child: tile(a))),
          const SizedBox(width: 4),
          Expanded(child: SizedBox.expand(child: tile(b))),
        ],
      ),
    );
    if (count == 2) return Row(children: [row(0, 1)]);
    return Column(children: [row(0, 1), const SizedBox(height: 4), row(2, 3)]);
  }
}
