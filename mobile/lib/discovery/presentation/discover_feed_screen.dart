import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../data/discovery_repository.dart';
import '../domain/candidate.dart';

/// docs/07-ui-ux-design.md §3.2's "Card stack" is swipe-gesture driven, but
/// the swipe action itself (POST /swipes, like/pass/match) is Phase 1 item
/// 6 — not built yet. Building drag-gesture UI now with nowhere for the
/// gesture to persist to would mean reworking it once item 6 lands. This is
/// a plain browsable list instead: real candidates, real pagination, no
/// pretend swipe buttons wired to nothing. Replace with the real card stack
/// when item 6 exists.
class DiscoverFeedScreen extends ConsumerStatefulWidget {
  const DiscoverFeedScreen({super.key});

  @override
  ConsumerState<DiscoverFeedScreen> createState() => _DiscoverFeedScreenState();
}

class _DiscoverFeedScreenState extends ConsumerState<DiscoverFeedScreen> {
  bool _loading = true;
  bool _loadingMore = false;
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

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final result = await ref.read(discoveryRepositoryProvider).getFeed(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page += 1;
        _candidates = [..._candidates, ...result.candidates];
        _hasMore = result.hasMore;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Discover')), body: SafeArea(child: _buildBody()));
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
        onAction: () => context.push('/onboarding/location').then((_) => _load()),
      );
    }

    if (_errorCode == 'preferences_required') {
      return _Guidance(
        icon: Icons.tune,
        message: 'Set your discovery preferences to get started.',
        actionLabel: 'Set preferences',
        onAction: () => context.push('/profile/preferences').then((_) => _load()),
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _candidates.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _candidates.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : TextButton(onPressed: _loadMore, child: const Text('Load more')),
              ),
            );
          }
          return _CandidateCard(candidate: _candidates[index]);
        },
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

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final DiscoveryCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: candidate.photos.isEmpty
                ? Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.person, size: 64),
                  )
                : Image.network(candidate.photos.first.url, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${candidate.displayName}, ${candidate.age}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (candidate.isVerified) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.verified, size: 16),
                    ],
                    const Spacer(),
                    Text(candidate.distanceLabel, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                if (candidate.bio != null && candidate.bio!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(candidate.bio!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
