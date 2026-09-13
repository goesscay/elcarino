import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../data/safety_repository.dart';
import '../domain/blocked_user.dart';

/// docs/07-ui-ux-design.md §3.7 "Blocked users (Settings child): List with
/// unblock."
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  bool _loading = true;
  String? _error;
  List<BlockedUser> _blockedUsers = [];

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
      final blockedUsers = await ref
          .read(safetyRepositoryProvider)
          .getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blockedUsers = blockedUsers;
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

  Future<void> _unblock(BlockedUser user) async {
    try {
      await ref.read(safetyRepositoryProvider).unblock(user.id);
      if (!mounted) return;
      setState(
        () => _blockedUsers = _blockedUsers
            .where((u) => u.id != user.id)
            .toList(),
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
      appBar: AppBar(title: const Text('Blocked users')),
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

    if (_blockedUsers.isEmpty) {
      return const Center(child: Text("You haven't blocked anyone."));
    }

    return ListView.builder(
      itemCount: _blockedUsers.length,
      itemBuilder: (context, index) {
        final user = _blockedUsers[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.photo == null
                ? null
                : NetworkImage(user.photo!.url),
            child: user.photo == null ? const Icon(Icons.person) : null,
          ),
          title: Text(user.displayName ?? 'Deactivated user'),
          trailing: OutlinedButton(
            onPressed: () => _unblock(user),
            child: const Text('Unblock'),
          ),
        );
      },
    );
  }
}
