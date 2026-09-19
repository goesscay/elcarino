import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/network_photo.dart';
import '../../core/widgets/state_message.dart';
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
      return StateMessage(
        icon: Icons.error_outline,
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_blockedUsers.isEmpty) {
      return const StateMessage(
        icon: Icons.block_rounded,
        title: 'No blocked users',
        message: "People you block won't be able to see or message you.",
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: _blockedUsers.length,
      separatorBuilder: (context, _) =>
          const Divider(indent: AppSpacing.screen + 48 + AppSpacing.lg),
      itemBuilder: (context, index) {
        final user = _blockedUsers[index];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: ClipOval(
                  child: user.photo == null
                      ? const PhotoPlaceholder(iconSize: 24)
                      : NetworkPhoto(user.photo!.url),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  user.displayName ?? 'Deactivated user',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Not full-width: the app's outlined-button theme is, so a
              // button in a Row states its own compact size.
              OutlinedButton(
                onPressed: () => _unblock(user),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                ),
                child: const Text('Unblock'),
              ),
            ],
          ),
        );
      },
    );
  }
}
