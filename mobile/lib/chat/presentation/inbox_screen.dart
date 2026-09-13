import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../matching/data/matching_repository.dart';
import '../data/chat_repository.dart';
import '../domain/conversation.dart';

/// docs/07-ui-ux-design.md §3.3 "Matches + inbox": top row of new matches
/// with no messages yet, conversation list below. Sourced from a single
/// `GET /chat/conversations` call — a fresh match already has a `Conversation`
/// row (created alongside the `UserMatch`, feature 6), so no separate
/// `GET /matches` call is needed to populate the top row.
///
/// Deliberately doesn't hold a live socket connection just to sit in the
/// inbox — opening a presence channel per conversation here would mean as
/// many WebSocket subscriptions as matches, for a screen that isn't even
/// displaying message content. Pull-to-refresh, plus a refresh on returning
/// from a conversation, is a reasonable trade for how live this list needs
/// to be; [ConversationScreen] is the one that holds a live channel.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  bool _loading = true;
  String? _error;
  List<Conversation> _conversations = [];

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
      final conversations = await ref
          .read(chatRepositoryProvider)
          .getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
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

  Future<void> _openConversation(Conversation conversation) async {
    await context.push('/chat/${conversation.id}', extra: conversation);
    // The conversation screen may have sent a first message, or marked
    // unread messages read, since this list was last loaded.
    await _load();
  }

  Future<void> _unmatch(Conversation conversation) async {
    final matchId = conversation.matchId;
    if (matchId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unmatch ${conversation.otherUser.displayName}?'),
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
      await ref.read(matchingRepositoryProvider).unmatch(matchId);
      if (!mounted) return;
      setState(
        () => _conversations = _conversations
            .where((c) => c.id != conversation.id)
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

    if (_conversations.isEmpty) {
      return const Center(child: Text('No matches yet — keep discovering.'));
    }

    final newMatches = _conversations.where((c) => !c.hasMessages).toList();
    final started = _conversations.where((c) => c.hasMessages).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (newMatches.isNotEmpty)
            _NewMatchesRow(matches: newMatches, onTap: _openConversation),
          if (started.isEmpty && newMatches.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Say hi to one of your new matches!',
                textAlign: TextAlign.center,
              ),
            ),
          for (final conversation in started)
            _ConversationTile(
              conversation: conversation,
              onTap: () => _openConversation(conversation),
              onUnmatch: () => _unmatch(conversation),
            ),
        ],
      ),
    );
  }
}

class _NewMatchesRow extends StatelessWidget {
  const _NewMatchesRow({required this.matches, required this.onTap});

  final List<Conversation> matches;
  final void Function(Conversation) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final conversation = matches[index];
          final photo = conversation.otherUser.photos.isEmpty
              ? null
              : conversation.otherUser.photos.first;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: GestureDetector(
              onTap: () => onTap(conversation),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: photo == null
                        ? null
                        : NetworkImage(photo.url),
                    child: photo == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: 64,
                    child: Text(
                      conversation.otherUser.displayName,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onUnmatch,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onUnmatch;

  @override
  Widget build(BuildContext context) {
    final photo = conversation.otherUser.photos.isEmpty
        ? null
        : conversation.otherUser.photos.first;
    final unread = conversation.unreadCount > 0;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: photo == null ? null : NetworkImage(photo.url),
        child: photo == null ? const Icon(Icons.person) : null,
      ),
      title: Text(conversation.otherUser.displayName),
      subtitle: Text(
        conversation.lastMessagePreview ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: unread ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (conversation.lastMessageAt != null)
            Text(
              _formatTimestamp(conversation.lastMessageAt!),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          if (unread)
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.xs),
              child: CircleAvatar(
                radius: 4,
                backgroundColor: AppColors.primary,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.person_remove_outlined),
            tooltip: 'Unmatch',
            onPressed: onUnmatch,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    if (now.difference(local).inHours < 24 && now.day == local.day) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return '${local.month}/${local.day}';
  }
}
