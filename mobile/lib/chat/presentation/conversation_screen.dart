import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

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
import '../domain/message_type.dart';
import '../domain/read_receipt.dart';

/// docs/07-ui-ux-design.md §3.3 "Conversation": message list (bubbles, own =
/// trailing), read receipt on the last own message, typing indicator,
/// online/last-active in the header. Composer has a single mic button for
/// voice notes (Phase 3 item 1, open decision #16) — deliberately not
/// docs/07's fuller "attachment button reveals voice/photo/GIF" menu, since
/// gif/photo (#17/#18) aren't built yet. Header overflow: Unmatch, Report,
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
  final _recorder = AudioRecorder();

  // Kept in sync manually with the backend's
  // config('media.max_voice_note_duration_seconds') default — there's no
  // runtime config-fetch endpoint for the client to read this from.
  static const _maxRecordingDuration = Duration(seconds: 120);

  ConversationChannel? _channel;
  StreamSubscription<Message>? _newMessageSub;
  StreamSubscription<ReadReceipt>? _readReceiptSub;
  StreamSubscription<void>? _typingSub;
  Timer? _typingResetTimer;
  Timer? _recordingTicker;
  DateTime? _lastTypingWhisperAt;

  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _recording = false;
  bool _sendingVoiceNote = false;
  Duration _recordingElapsed = Duration.zero;
  bool _otherIsTyping = false;
  String? _error;
  List<Message> _messages = [];
  int _nextPage = 1;
  bool _hasMore = false;
  DateTime? _otherReadUpTo;

  /// Phase 2 item 4: mutable, not `widget.conversation.requiresSubscriptionToMessage`
  /// directly — after the user subscribes from the banner below and comes
  /// back, this needs to flip without a full navigation round-trip back
  /// through `InboxScreen`/`ConversationLoaderScreen` to get a fresh
  /// `Conversation`. Everything else this screen reads off
  /// `widget.conversation` is immutable for the life of a conversation
  /// (participants, match id), so only this one field needs its own state.
  late bool _requiresSubscriptionToMessage =
      widget.conversation.requiresSubscriptionToMessage;

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

  /// Phase 2 item 4. Called after the user returns from the Premium screen
  /// via the banner's "Upgrade" button — there's no `GET
  /// /chat/conversations/{id}` (docs/03), so this reuses the same "list +
  /// find by id" approach ConversationLoaderScreen already uses, rather
  /// than adding a single-resource endpoint just for this refresh.
  Future<void> _refreshSubscriptionRequirement() async {
    try {
      final conversations = await ref
          .read(chatRepositoryProvider)
          .getConversations();
      Conversation? refreshed;
      for (final c in conversations) {
        if (c.id == widget.conversation.id) {
          refreshed = c;
          break;
        }
      }
      if (!mounted || refreshed == null) return;
      final stillRequiresSubscription = refreshed.requiresSubscriptionToMessage;
      setState(
        () => _requiresSubscriptionToMessage = stillRequiresSubscription,
      );
    } on ApiException {
      // Best-effort — worst case the banner just stays up until the next
      // natural reload (e.g. reopening the conversation).
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

  /// Prepends [message] unless it's already present. Needed on *both* paths
  /// a message can arrive: the `message.new` broadcast (`ShouldBroadcastNow`
  /// — synchronous, so it can reach this device over the socket before the
  /// sender's own HTTP response comes back) and the HTTP response itself
  /// from `_send`/`_stopAndSendRecording`. Caught live testing voice notes:
  /// without this same check on the HTTP-response side, a self-sent message
  /// reliably rendered twice — the socket echo added it first, then the
  /// HTTP response's own unconditional prepend added it again. Pre-existing
  /// for text sends too (`_send` had no dedup at all before this), just
  /// never visibly triggered until this feature's live pass.
  bool _appendMessageIfNew(Message message) {
    if (_messages.any((m) => m.id == message.id)) return false;
    setState(() => _messages = [message, ..._messages]);
    return true;
  }

  void _handleIncomingMessage(Message message) {
    if (!mounted) return;
    if (!_appendMessageIfNew(message)) {
      return; // already have it (own optimistic add)
    }
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
      _appendMessageIfNew(message);
      setState(() => _sending = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Tap-to-start/tap-to-stop, not press-and-hold — a disclosed
  /// simplification of docs/07's implied recording gesture, same spirit as
  /// this screen's other "simpler but functionally equivalent" choices
  /// (left/right reorder buttons instead of drag, in PhotosScreen).
  /// Microphone permission is requested here, at point of use, matching the
  /// existing location/notification permission pattern (requested where
  /// needed, not batched into onboarding).
  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted || !await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone access is needed to record a voice note.'),
        ),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice-note-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;

    setState(() {
      _recording = true;
      _recordingElapsed = Duration.zero;
    });
    _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordingElapsed += const Duration(seconds: 1));
      if (_recordingElapsed >= _maxRecordingDuration) {
        _stopAndSendRecording();
      }
    });
  }

  Future<void> _cancelRecording() async {
    _recordingTicker?.cancel();
    await _recorder.stop();
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTicker?.cancel();
    final path = await _recorder.stop();
    final duration = _recordingElapsed;
    if (!mounted) return;
    setState(() => _recording = false);

    // Below the backend's own `duration_seconds` min:1 — discard quietly
    // rather than round-tripping to the API for a validation error over
    // what was obviously an accidental tap.
    if (path == null || duration.inSeconds < 1) return;

    setState(() => _sendingVoiceNote = true);
    try {
      final message = await ref
          .read(chatRepositoryProvider)
          .sendVoiceNote(widget.conversation.id, path, duration.inSeconds);
      if (!mounted) return;
      _appendMessageIfNew(message);
      setState(() => _sendingVoiceNote = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sendingVoiceNote = false);
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
    _recordingTicker?.cancel();
    _recorder.dispose();
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
            if (_requiresSubscriptionToMessage)
              _SubscriptionRequiredBanner(
                onUpgrade: () async {
                  await context.push('/settings/subscription');
                  await _refreshSubscriptionRequirement();
                },
              )
            else if (_recording)
              _RecordingIndicator(
                elapsed: _recordingElapsed,
                onCancel: _cancelRecording,
                onStop: _stopAndSendRecording,
              )
            else
              _Composer(
                controller: _composerController,
                sending: _sending,
                sendingVoiceNote: _sendingVoiceNote,
                onChanged: _onComposerChanged,
                onSend: _send,
                onStartRecording: _startRecording,
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
          // The list prepends new messages (`_handleIncomingMessage`/`_send`),
          // which shifts every existing bubble's builder index — a stable key
          // keeps _VoiceNotePlayer's per-message AudioPlayer state (and
          // playback position) from getting reassigned to the wrong message
          // across a rebuild.
          key: ValueKey(message.id),
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
    super.key,
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
              child: message.type == MessageType.voiceNote
                  ? (message.attachment == null
                        ? const Text('Voice note unavailable')
                        : _VoiceNotePlayer(
                            attachment: message.attachment!,
                            isMine: isMine,
                          ))
                  : Text(
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
    required this.sendingVoiceNote,
    required this.onChanged,
    required this.onSend,
    required this.onStartRecording,
  });

  final TextEditingController controller;
  final bool sending;
  final bool sendingVoiceNote;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onStartRecording;

  @override
  Widget build(BuildContext context) {
    final busy = sending || sendingVoiceNote;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: busy ? null : onStartRecording,
            icon: sendingVoiceNote
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mic_none),
          ),
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
            onPressed: busy ? null : onSend,
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

/// Shown in place of [_Composer] while recording — tap the stop button to
/// send, the trash button to discard. Tap-to-start/tap-to-stop, not
/// press-and-hold (see [_ConversationScreenState._startRecording]'s doc).
class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({
    required this.elapsed,
    required this.onCancel,
    required this.onStop,
  });

  final Duration elapsed;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          ),
          const Icon(
            Icons.fiber_manual_record,
            color: AppColors.danger,
            size: 14,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Recording… $minutes:${seconds.toString().padLeft(2, '0')}',
            ),
          ),
          IconButton.filled(onPressed: onStop, icon: const Icon(Icons.stop)),
        ],
      ),
    );
  }
}

/// A message bubble's inline voice-note player. Keyed per-message
/// ([_MessageBubble]'s key) so its [AudioPlayer] and playback position stay
/// tied to the right message as the list is prepended to.
///
/// Playback over the signed URL is verified live on the Android emulator —
/// it wasn't on the first pass (`adb logcat` showed
/// `NuCachedSource2: source returned error -1`), which turned out to be
/// three stacked issues, not one: (1) no `network_security_config.xml`
/// exception meant Android's native networking layer (what `audioplayers`'
/// underlying `MediaPlayer` goes through) silently refused the plain-`http`
/// connection to the dev backend before it ever left the device — Dart's own
/// `dart:io` HTTP client (what the JSON API calls use) doesn't consult that
/// policy at all, so every other network call in the app kept working the
/// whole time, which is what made this confusing to isolate; see
/// `android/app/src/debug/res/xml/network_security_config.xml`. (2) and (3)
/// were server-side — see `MessageAttachmentStreamController`'s and
/// `AudioMimeTypeResolver`'s doc comments.
class _VoiceNotePlayer extends StatefulWidget {
  const _VoiceNotePlayer({required this.attachment, required this.isMine});

  final MessageAttachment attachment;
  final bool isMine;

  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<_VoiceNotePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _duration = widget.attachment.durationSeconds == null
        ? null
        : Duration(seconds: widget.attachment.durationSeconds!);
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
  }

  /// The attachment's `url` is a short-lived signed URL
  /// (`media.chat_media_signed_url_ttl_minutes`) resolved once when this
  /// [Message] was fetched/received — not cached or refreshed here, so a
  /// bubble scrolled back to long after the link expired will fail to play.
  /// No retry/refetch exists yet for that edge case (there's no single-
  /// message refetch endpoint — see `_refreshSubscriptionRequirement`'s doc
  /// for the same "list + find by id" limitation elsewhere in this screen).
  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.attachment.url));
    }
    if (mounted) setState(() => _playing = !_playing);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMine
        ? AppColors.onPrimary
        : AppColors.textPrimaryLight;
    final total = _duration ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : _position.inMilliseconds / total.inMilliseconds;
    final minutes = total.inMinutes;
    final seconds = total.inSeconds % 60;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _toggle,
          icon: Icon(
            _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: color,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              color: color,
              backgroundColor: color.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$minutes:${seconds.toString().padLeft(2, '0')}',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}

/// docs/07 §3.3 "Unmatched-conversation banner": composer disabled, inline
/// banner. Phase 1 left it as inert text — subscriptions didn't exist yet,
/// so the flag was effectively always a hard stop, not a soft upsell.
/// Phase 2 item 4 ("adds ... the upgrade-prompt UX around it") makes it
/// tappable, straight to PremiumScreen — the same disclosed simplification
/// item 2's advanced-filters lock and item 3's boost sheet already use
/// instead of docs/07's more elaborate generic paywall-modal concept.
class _SubscriptionRequiredBanner extends StatelessWidget {
  const _SubscriptionRequiredBanner({required this.onUpgrade});

  final Future<void> Function() onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surfaceLight,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Subscribe to message people you haven't matched with.",
            ),
          ),
          TextButton(onPressed: onUpgrade, child: const Text('Upgrade')),
        ],
      ),
    );
  }
}
