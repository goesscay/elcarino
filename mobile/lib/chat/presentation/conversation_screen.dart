import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../matching/data/matching_repository.dart';
import '../../matching/presentation/unmatch_confirm_dialog.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/block_confirm_dialog.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket_service.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';
import '../domain/read_receipt.dart';

/// docs/07-ui-ux-design.md §3.3 "Conversation": message list (bubbles, own =
/// trailing), read receipt on the last own message, typing indicator,
/// online/last-active in the header. No attachment button — voice
/// note/photo/GIF are [TBD-16/17/18], out of this feature's text-only scope
/// (docs/03-api-specification.md "Chat"). Header overflow: Unmatch, Report,
/// Block (item 10) — "View profile" isn't built, no such screen exists yet
/// for viewing another user's full profile outside a match/discovery card.
enum _ConversationMenuAction { unmatch, report, block }

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.conversation, super.key});

  final Conversation conversation;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();

  ConversationChannel? _channel;
  StreamSubscription<Message>? _newMessageSub;
  StreamSubscription<ReadReceipt>? _readReceiptSub;
  StreamSubscription<void>? _typingSub;
  Timer? _typingResetTimer;
  DateTime? _lastTypingWhisperAt;

  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _otherIsTyping = false;
  String? _error;
  List<Message> _messages = [];
  int _nextPage = 1;
  bool _hasMore = false;
  DateTime? _otherReadUpTo;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _init();
  }

  Future<void> _init() async {
    await _loadFirstPage();
    unawaited(_markRead());
    await _connectSocket();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .getMessages(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = page.messages;
        _hasMore = page.hasMore;
        _nextPage = 2;
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
    if (_loadingMore || !_hasMore) return;
    // Reversed list: "load more (older)" happens near the *max* scroll
    // extent, which is the oldest end of a newest-first message list.
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .getMessages(widget.conversation.id, page: _nextPage);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, ...page.messages];
        _hasMore = page.hasMore;
        _nextPage++;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await ref.read(chatRepositoryProvider).markRead(widget.conversation.id);
    } on ApiException {
      // Best-effort — an unread badge staying lit is a cosmetic miss, not
      // worth surfacing an error for.
    }
  }

  Future<void> _connectSocket() async {
    final socketService = ref.read(chatSocketServiceProvider);
    await socketService.connect();
    if (!mounted) return;
    final channel = socketService.joinConversation(widget.conversation.id);
    _channel = channel;
    _newMessageSub = channel.onNewMessage.listen(_handleIncomingMessage);
    _readReceiptSub = channel.onMessagesRead.listen(_handleReadReceipt);
    _typingSub = channel.onTyping.listen((_) => _handleTypingSignal());
  }

  void _handleIncomingMessage(Message message) {
    if (!mounted) return;
    if (_messages.any((m) => m.id == message.id)) {
      return; // already have it (own optimistic add)
    }
    setState(() => _messages = [message, ..._messages]);
    // A conversation is always exactly two people (docs/02-database-schema.md
    // `conversations`), so "sent by the other participant" is simply "sent
    // by `Conversation.otherUser`'s id" — no separate "my user id" call is
    // needed (`core/auth` deliberately holds no user data).
    if (message.senderId == widget.conversation.otherUser.id) {
      // Mark it read immediately so the inbox's unread badge stays accurate.
      unawaited(_markRead());
    }
  }

  void _handleReadReceipt(ReadReceipt receipt) {
    if (!mounted) return;
    if (receipt.readByUserId != widget.conversation.otherUser.id) return;
    setState(() => _otherReadUpTo = receipt.readAt);
  }

  void _handleTypingSignal() {
    if (!mounted) return;
    setState(() => _otherIsTyping = true);
    _typingResetTimer?.cancel();
    _typingResetTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _otherIsTyping = false);
    });
  }

  void _onComposerChanged(String text) {
    if (text.isEmpty) return;
    final now = DateTime.now();
    // Throttle — no need to whisper on every keystroke.
    if (_lastTypingWhisperAt != null &&
        now.difference(_lastTypingWhisperAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastTypingWhisperAt = now;
    _channel?.sendTyping();
  }

  Future<void> _send() async {
    final body = _composerController.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final message = await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.conversation.id, body);
      if (!mounted) return;
      _composerController.clear();
      setState(() {
        _messages = [message, ..._messages];
        _sending = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _handleMenuAction(_ConversationMenuAction action) async {
    switch (action) {
      case _ConversationMenuAction.unmatch:
        await _unmatch();
      case _ConversationMenuAction.report:
        await _report();
      case _ConversationMenuAction.block:
        await _block();
    }
  }

  Future<void> _unmatch() async {
    final matchId = widget.conversation.matchId;
    if (matchId == null) return;

    final confirmed = await showUnmatchConfirmDialog(
      context,
      widget.conversation.otherUser.displayName,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(matchingRepositoryProvider).unmatch(matchId);
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _report() async {
    await context.push(
      '/safety/report',
      extra: (
        widget.conversation.otherUser.id,
        widget.conversation.otherUser.displayName,
      ),
    );
  }

  Future<void> _block() async {
    final confirmed = await showBlockConfirmDialog(
      context,
      widget.conversation.otherUser.displayName,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(safetyRepositoryProvider)
          .block(widget.conversation.otherUser.id);
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    _composerController.dispose();
    _newMessageSub?.cancel();
    _readReceiptSub?.cancel();
    _typingSub?.cancel();
    _typingResetTimer?.cancel();
    // Leave the presence channel so the member list (the online/offline
    // signal) reflects that this device is no longer actually looking.
    ref
        .read(chatSocketServiceProvider)
        .leaveConversation(widget.conversation.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherUser = widget.conversation.otherUser;
    final isOnline =
        _channel?.onlineMembers.any((m) => m.id == otherUser.id.toString()) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(otherUser.displayName),
            Text(
              _otherIsTyping ? 'Typing…' : (isOnline ? 'Online' : ''),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_ConversationMenuAction>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              if (widget.conversation.matchId != null)
                const PopupMenuItem(
                  value: _ConversationMenuAction.unmatch,
                  child: Text('Unmatch'),
                ),
              const PopupMenuItem(
                value: _ConversationMenuAction.report,
                child: Text('Report'),
              ),
              const PopupMenuItem(
                value: _ConversationMenuAction.block,
                child: Text('Block'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            if (widget.conversation.requiresSubscriptionToMessage)
              _SubscriptionRequiredBanner()
            else
              _Composer(
                controller: _composerController,
                sending: _sending,
                onChanged: _onComposerChanged,
                onSend: _send,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
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
              FilledButton(
                onPressed: _loadFirstPage,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('You matched — say hi!'));
    }

    final lastOwnMessageId = _messages
        .firstWhere(
          (m) => m.senderId != widget.conversation.otherUser.id,
          orElse: () => _messages.first,
        )
        .id;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _messages.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final message = _messages[index];
        final isMine = message.senderId != widget.conversation.otherUser.id;
        final showReadReceipt =
            isMine &&
            message.id == lastOwnMessageId &&
            _otherReadUpTo != null &&
            !message.createdAt.isAfter(_otherReadUpTo!);
        return _MessageBubble(
          message: message,
          isMine: isMine,
          showReadReceipt: showReadReceipt,
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showReadReceipt,
  });

  final Message message;
  final bool isMine;
  final bool showReadReceipt;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(
                message.body ?? '',
                style: TextStyle(
                  color: isMine
                      ? AppColors.onPrimary
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            if (showReadReceipt)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Read',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Message…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

/// docs/07 §3.3 "Unmatched-conversation banner": composer disabled, inline
/// banner. Doesn't link to a paywall — that's Phase 2 (subscriptions aren't
/// built yet, so nobody in Phase 1 can actually be a subscriber; this flag
/// is effectively always a hard stop for now, not a soft upsell).
class _SubscriptionRequiredBanner extends StatelessWidget {
  const _SubscriptionRequiredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surfaceLight,
      child: const Text(
        "Subscribe to message people you haven't matched with.",
        textAlign: TextAlign.center,
      ),
    );
  }
}
