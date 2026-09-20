import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/state_message.dart';
import '../../discovery/domain/candidate.dart';
import '../../discovery/presentation/person_tile.dart';
import '../data/explore_repository.dart';
import '../domain/explore_interest.dart';

/// The people behind one Explore tile: a grid of everyone the viewer could be
/// shown who shares [interest], in the Discover deck's own order. Tapping
/// someone opens their full profile with Like / Pass; once answered (or
/// blocked) they leave the grid.
class ExplorePeopleScreen extends ConsumerStatefulWidget {
  const ExplorePeopleScreen({required this.interest, super.key});

  final ExploreInterest interest;

  @override
  ConsumerState<ExplorePeopleScreen> createState() =>
      _ExplorePeopleScreenState();
}

class _ExplorePeopleScreenState extends ConsumerState<ExplorePeopleScreen> {
  final _scroll = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<DiscoveryCandidate> _people = [];
  int _total = 0;
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(exploreRepositoryProvider)
          .getPeople(widget.interest.id);
      if (!mounted) return;
      setState(() {
        _people = page.people;
        _total = page.total;
        _hasMore = page.hasMore;
        _page = 1;
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

  void _maybeLoadMore() {
    if (!_scroll.hasClients || _loadingMore || !_hasMore) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(exploreRepositoryProvider)
          .getPeople(widget.interest.id, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page += 1;
        _people = [..._people, ...page.people];
        _hasMore = page.hasMore;
      });
    } on ApiException {
      // Soft-fail: stop topping up; what's loaded stays usable.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(DiscoveryCandidate person) async {
    final dealtWith = await context.push<bool>(
      '/profile/candidate',
      extra: (person, true),
    );
    if (dealtWith == true && mounted) {
      setState(() {
        _people = _people.where((c) => c.id != person.id).toList();
        _total = _total > 0 ? _total - 1 : 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.interest.name)),
      body: SafeArea(child: _buildBody(text)),
    );
  }

  Widget _buildBody(TextTheme text) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return StateMessage(
        icon: Icons.error_outline,
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_people.isEmpty) {
      return StateMessage(
        icon: Icons.favorite_border_rounded,
        title: "You've seen everyone here",
        message: 'No one else nearby shares ${widget.interest.name} right now.',
        actionLabel: 'Back to Explore',
        onAction: () => context.pop(),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.xs,
            AppSpacing.screen,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _total == 1
                  ? '1 person shares this'
                  : '$_total people share this',
              style: text.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
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
              itemCount: _people.length,
              itemBuilder: (context, index) => PersonTile(
                candidate: _people[index],
                onTap: () => _open(_people[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
