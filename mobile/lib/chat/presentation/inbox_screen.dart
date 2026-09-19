import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/tab_refresh.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/network_photo.dart';
import '../../core/widgets/state_message.dart';
import '../../matching/data/matching_repository.dart';
import '../../matching/presentation/unmatch_confirm_dialog.dart';
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
///
/// Unmatch lives behind a long-press (and, for screen readers, a custom
/// action) rather than an icon on every row — a column of identical "remove"
/// buttons is visual noise on a list you mostly read. It's also in the
/// conversation's own overflow menu.
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
      // Only blank the screen for the very first load; a reload (tab
      // re-selected, pull-to-refresh, back from a chat) refreshes in place
      // instead of flashing the list away.
      _loading = _conversations.isEmpty;
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

    final confirmed = await showUnmatchConfirmDialog(
      context,
      conversation.otherUser.displayName,
    );
    if (!confirmed) return;

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

  /// Long-press: a small sheet offering Unmatch (which then confirms).
  Future<void> _showActions(Conversation conversation) async {
    if (conversation.matchId == null) return;
    final unmatch = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            leading: const Icon(
              Icons.person_remove_outlined,
              color: AppColors.danger,
            ),
            title: Text(
              'Unmatch ${conversation.otherUser.displayName}',
              style: const TextStyle(color: AppColors.danger),
            ),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
        ),
      ),
    );
    if (unmatch == true && mounted) await _unmatch(conversation);
  }

  @override
  Widget build(BuildContext context) {
    // The tab shell keeps this screen alive across tab switches, so reload
    // whenever the Chats tab is (re)selected — see ChatsTabRefresh.
    ref.listen(chatsTabRefreshProvider, (previous, next) => _load());

    return Scaffold(
      appBar: AppBar(
        title: Text('Chats', style: Theme.of(context).textTheme.headlineMedium),
        toolbarHeight: 64,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _InboxSkeleton();

    if (_error != null) {
      return StateMessage(
        icon: Icons.error_outline,
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_conversations.isEmpty) {
      return StateMessage(
        icon: Icons.chat_bubble_outline,
        title: 'No matches yet',
        message: 'When you and someone like each other, you can chat here.',
        actionLabel: 'Keep discovering',
        onAction: () => context.go('/discover'),
      );
    }

    final newMatches = _conversations.where((c) => !c.hasMessages).toList();
    final started = _conversations.where((c) => c.hasMessages).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (newMatches.isNotEmpty) ...[
            const _SectionLabel('New matches'),
            _NewMatchesRow(matches: newMatches, onTap: _openConversation),
          ],
          if (started.isNotEmpty) ...[
            if (newMatches.isNotEmpty) const _SectionLabel('Messages'),
            for (var i = 0; i < started.length; i++) ...[
              _ConversationTile(
                conversation: started[i],
                onTap: () => _openConversation(started[i]),
                onUnmatch: () => _unmatch(started[i]),
                onLongPress: () => _showActions(started[i]),
              ),
              if (i < started.length - 1)
                Divider(
                  indent: _ConversationTile.textIndent,
                  endIndent: AppSpacing.screen,
                ),
            ],
          ] else if (newMatches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Say hi to one of your new matches!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.palette.textSecondary),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        AppSpacing.sm,
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// A person's photo as a circle; [ringed] draws the brand-red ring used to
/// mark a match you haven't said anything to yet.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size, this.ringed = false});

  final String? url;
  final double size;
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    final photo = SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: url == null
            ? const PhotoPlaceholder(iconSize: 26)
            : NetworkPhoto(url!),
      ),
    );
    if (!ringed) return photo;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Padding(padding: const EdgeInsets.all(3), child: photo),
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
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final conversation = matches[index];
          final photos = conversation.otherUser.photos;
          final name = conversation.otherUser.displayName;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Semantics(
              button: true,
              label: 'New match: $name',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => onTap(conversation),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Avatar(
                        url: photos.isEmpty ? null : photos.first.url,
                        size: 62,
                        ringed: true,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
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
    required this.onLongPress,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onUnmatch;
  final VoidCallback onLongPress;

  static const _avatarSize = 56.0;

  /// Left inset where the name/preview text starts — the divider lines up
  /// with it rather than running under the avatar.
  static const textIndent = AppSpacing.screen + _avatarSize + AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final photos = conversation.otherUser.photos;
    final unread = conversation.unreadCount;
    final hasUnread = unread > 0;
    final name = conversation.otherUser.displayName;
    final preview = conversation.lastMessagePreview ?? '';
    final time = conversation.lastMessageAt == null
        ? ''
        : formatChatTimestamp(conversation.lastMessageAt!);

    return Semantics(
      button: true,
      label: [
        name,
        if (hasUnread) '$unread unread',
        if (preview.isNotEmpty) preview,
        if (time.isNotEmpty) time,
      ].join(', '),
      customSemanticsActions: {
        if (conversation.matchId != null)
          const CustomSemanticsAction(label: 'Unmatch'): onUnmatch,
      },
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              _Avatar(
                url: photos.isEmpty ? null : photos.first.url,
                size: _avatarSize,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        color: hasUnread ? p.textPrimary : p.textSecondary,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: text.labelSmall?.copyWith(
                        color: hasUnread ? AppColors.primary : p.textSecondary,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  if (hasUnread) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _UnreadBadge(count: unread),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

/// A calm placeholder while the first load is in flight — rows the shape of
/// the real ones, in the neutral fill, so the layout doesn't jump when the
/// content arrives.
class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    final fill = context.palette.fill;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screen,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(120, 14),
                      const SizedBox(height: AppSpacing.sm),
                      bar(200, 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A chat row's timestamp: the time today, "Yesterday", the weekday within the
/// past week, otherwise month/day. [now] is injectable for tests.
String formatChatTimestamp(DateTime dateTime, {DateTime? now}) {
  final current = (now ?? DateTime.now());
  final local = dateTime.toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(local.year, local.month, local.day);
  final daysAgo = today.difference(day).inDays;

  if (daysAgo <= 0) {
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  if (daysAgo == 1) return 'Yesterday';
  if (daysAgo < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[local.weekday - 1];
  }
  return '${local.month}/${local.day}';
}
