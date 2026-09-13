import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../data/matching_repository.dart';
import '../domain/match.dart';

/// docs/07-ui-ux-design.md §3.3 "Matches + inbox": this is just the matches
/// half — "new matches with no messages yet" plus the conversation list
/// below it need Chat (Phase 1 item 8), which doesn't exist yet. A plain
/// list of active matches with an unmatch action, not the full inbox screen.
class MatchesListScreen extends ConsumerStatefulWidget {
  const MatchesListScreen({super.key});

  @override
  ConsumerState<MatchesListScreen> createState() => _MatchesListScreenState();
}

class _MatchesListScreenState extends ConsumerState<MatchesListScreen> {
  bool _loading = true;
  String? _error;
  List<UserMatch> _matches = [];

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
      final matches = await ref.read(matchingRepositoryProvider).getMatches();
      if (!mounted) return;
      setState(() {
        _matches = matches;
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

  Future<void> _unmatch(UserMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unmatch ${match.otherUser.displayName}?'),
        content: const Text("You won't see each other again in Discover."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unmatch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(matchingRepositoryProvider).unmatch(match.id);
      if (!mounted) return;
      setState(
        () => _matches = _matches.where((m) => m.id != match.id).toList(),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_matches.isEmpty) {
      return const Center(child: Text('No matches yet — keep discovering.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _matches.length,
        itemBuilder: (context, index) {
          final match = _matches[index];
          final photo = match.otherUser.photos.isEmpty
              ? null
              : match.otherUser.photos.first;
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: photo == null ? null : NetworkImage(photo.url),
              child: photo == null ? const Icon(Icons.person) : null,
            ),
            title: Text(
              '${match.otherUser.displayName}, ${match.otherUser.age}',
            ),
            subtitle: const Text('Say hi! (chat is coming soon)'),
            trailing: IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: 'Unmatch',
              onPressed: () => _unmatch(match),
            ),
          );
        },
      ),
    );
  }
}
