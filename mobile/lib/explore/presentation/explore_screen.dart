import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/tab_refresh.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/state_message.dart';
import '../data/explore_repository.dart';
import '../domain/explore_interest.dart';

/// docs/07 §2.1 "Explore": browse people by what they're into instead of one
/// at a time. A grid of interest tiles, each with how many people you could
/// actually be shown who share it (most popular first); tap one for those
/// people. Category chips narrow the grid and the search icon filters it by
/// name — both client-side, the list is a couple of dozen tiles.
///
/// The counts come from the same eligibility as the Discover deck (your filters,
/// distance, blocks and earlier swipes), so a tile never promises someone the
/// deck wouldn't show. They can move as you swipe, so the screen refreshes when
/// you come back to it and when you return from a category.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = TextEditingController();

  bool _loading = true;

  /// Whether a load has ever succeeded, so a reload keeps the grid on screen
  /// instead of flashing a spinner.
  bool _loaded = false;
  String? _errorCode;
  String? _errorMessage;
  List<ExploreInterest> _interests = [];
  String? _category;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = !_loaded;
      _errorCode = null;
    });
    try {
      final interests = await ref
          .read(exploreRepositoryProvider)
          .getInterests();
      if (!mounted) return;
      setState(() {
        _interests = interests;
        _loading = false;
        _loaded = true;
        // A category that no longer has any tile shouldn't stay selected.
        if (_category != null &&
            !interests.any((i) => i.category == _category)) {
          _category = null;
        }
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

  Future<void> _open(ExploreInterest interest) async {
    await context.push('/explore/interest', extra: interest);
    // Swiping in there changes every count.
    if (mounted) await _load();
  }

  List<String> get _categories =>
      ({for (final i in _interests) ?i.category}.toList()..sort());

  List<ExploreInterest> get _visible {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final i in _interests)
        if ((_category == null || i.category == _category) &&
            (query.isEmpty || i.name.toLowerCase().contains(query)))
          i,
    ];
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reload when the Explore tab is (re)selected.
    ref.listen(exploreTabRefreshProvider, (previous, next) => _load());

    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text('Explore', style: text.headlineMedium),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search interests',
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: _loaded ? _toggleSearch : null,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(child: _buildBody(text)),
    );
  }

  Widget _buildBody(TextTheme text) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_errorCode == 'location_required') {
      return StateMessage(
        icon: Icons.location_off_outlined,
        message: 'Turn on location to explore people nearby.',
        actionLabel: 'Set location',
        onAction: () =>
            context.push('/onboarding/location').then((_) => _load()),
      );
    }

    if (_errorCode == 'preferences_required') {
      return StateMessage(
        icon: Icons.tune,
        message: 'Set your discovery preferences to start exploring.',
        actionLabel: 'Set preferences',
        onAction: () => context.push('/discover/filters').then((_) => _load()),
      );
    }

    if (_errorCode != null && !_loaded) {
      return StateMessage(
        icon: Icons.error_outline,
        message: _errorMessage ?? 'Something went wrong.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_interests.isEmpty) {
      return const StateMessage(
        icon: Icons.explore_outlined,
        title: 'Nothing to explore yet',
        message:
            'When people nearby add interests, the categories show up here.',
      );
    }

    final visible = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.md,
          ),
          child: _searching
              ? TextField(
                  controller: _search,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search interests',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Find people who share your interests',
                    style: text.bodySmall,
                  ),
                ),
        ),
        _CategoryChips(
          categories: _categories,
          selected: _category,
          onSelected: (c) => setState(() => _category = c),
        ),
        Expanded(
          child: visible.isEmpty
              ? const StateMessage(
                  icon: Icons.search_off,
                  message: 'No interests match that.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.screen),
                    // A fixed height that grows with the OS text size, so a
                    // two-line name ("Gym & fitness") always fits its tile.
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisExtent: InterestTile.heightFor(context),
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) => InterestTile(
                      interest: visible[index],
                      onTap: () => _open(visible[index]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// "All" plus one chip per category that has a tile.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        children: [
          for (final category in [null, ...categories])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(category ?? 'All'),
                selected: selected == category,
                onSelected: (_) => onSelected(category),
              ),
            ),
        ],
      ),
    );
  }
}

/// The icon that stands in for a category on its tiles. Unknown or missing
/// categories get a neutral one, so a new category never breaks the grid.
IconData interestIcon(String? category) => switch (category) {
  'Sports' => Icons.fitness_center_rounded,
  'Arts' => Icons.palette_outlined,
  'Food & drink' => Icons.restaurant_rounded,
  'Lifestyle' => Icons.spa_outlined,
  'Learning' => Icons.school_outlined,
  _ => Icons.interests_outlined,
};

/// One interest: an icon, its name and how many people share it. A small tick
/// marks the ones already on your own profile.
class InterestTile extends StatelessWidget {
  const InterestTile({required this.interest, required this.onTap, super.key});

  final ExploreInterest interest;
  final VoidCallback onTap;

  /// Icon + a two-line name + the count, plus padding, at the current text
  /// scale.
  static double heightFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return 96 + 62 * scale.clamp(1.0, 2.0);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label:
          '${interest.name}, ${interest.peopleLabel}'
          '${interest.isYours ? ', on your profile' : ''}',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.primaryTint,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          interestIcon(interest.category),
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (interest.isYours)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  interest.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  interest.peopleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
