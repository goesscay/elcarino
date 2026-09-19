import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../calls/domain/call.dart';
import '../../calls/domain/call_type.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/network_photo.dart';
import '../../core/widgets/state_message.dart';
import '../../matching/data/matching_repository.dart';
import '../../matching/presentation/unmatch_confirm_dialog.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/block_confirm_dialog.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket_service.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';
import '../domain/read_receipt.dart';
import 'chat_formatting.dart';
import 'gif_picker_sheet.dart';
import 'message_widgets.dart';

/// docs/07-ui-ux-design.md §3.3 "Conversation": message list (bubbles, own =
/// trailing), read receipt on the last own message, typing indicator,
/// online/last-active in the header. Composer's single "+" button reveals a
/// voice note (#16) / photo (#18) / GIF (#17) menu, per docs/07 — now that
/// all three are built, matching the spec as written rather than the
/// disclosed-simplification "separate always-visible buttons" this screen
/// used while only some existed. Header overflow: Unmatch, Report,
/// Block (item 10) — "View profile" isn't built, no such screen exists yet
/// for viewing another user's full profile outside a match/discovery card.
enum _ConversationMenuAction { unmatch, report, block }

enum _AttachmentAction { voiceNote, photo, gif }

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
  final _imagePicker = ImagePicker();

  // Kept in sync manually with the backend's
  // config('media.max_voice_note_duration_seconds') default — there's no
  // runtime config-fetch endpoint for the client to read this from.
  static const _maxRecordingDuration = Duration(seconds: 120);

  ConversationChannel? _channel;
  StreamSubscription<Message>? _newMessageSub;
  StreamSubscription<ReadReceipt>? _readReceiptSub;
  StreamSubscription<void>? _typingSub;
  StreamSubscription<Call>? _callIncomingSub;
  Timer? _typingResetTimer;
  Timer? _recordingTicker;
  DateTime? _lastTypingWhisperAt;

  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _recording = false;
  bool _sendingVoiceNote = false;
  bool _sendingGif = false;
  bool _sendingPhoto = false;
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
    // Phase 3 items 4/5 — this is the entire "does an incoming call reach
    // the callee" mechanism (see CallController's doc comment): only fires
    // while this screen is open and subscribed, same scope disclosed there.
    _callIncomingSub = channel.onCallIncoming.listen(_handleIncomingCall);
  }

  /// The `call.incoming` broadcast reaches *both* participants on this
  /// channel — including the caller's own other-open instance of this
  /// screen (backgrounded under the `CallScreen` it just pushed itself, via
  /// the composer's call buttons, a direct user action, not this listener).
  /// Same "sent by the other participant" test `_handleIncomingMessage`
  /// already uses for the identical reason: this device has no notion of
  /// "my own user id" to compare against directly (`core/auth` deliberately
  /// holds none), so "the caller is the other participant" is how it's
  /// inferred instead.
  void _handleIncomingCall(Call call) {
    if (!mounted || call.caller.id != widget.conversation.otherUser.id) {
      return;
    }
    context.push('/calls', extra: (widget.conversation, call.type, call));
  }

  void _startCall(CallType type) {
    context.push('/calls', extra: (widget.conversation, type, null));
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

  /// Phase 3 item 2 (gifs, open decision #17). The sheet returns the
  /// picked [GifResult]; only its `id` is sent — `ChatRepository.sendGif`'s
  /// signature doesn't even accept a url, so there's no way to accidentally
  /// send one (see that method's doc comment for why).
  Future<void> _pickAndSendGif() async {
    final gif = await showGifPickerSheet(context);
    if (gif == null || !mounted) return;

    setState(() => _sendingGif = true);
    try {
      final message = await ref
          .read(chatRepositoryProvider)
          .sendGif(widget.conversation.id, gif.id);
      if (!mounted) return;
      _appendMessageIfNew(message);
      setState(() => _sendingGif = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sendingGif = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Phase 3 item 3 (photo sharing, open decision #18). Same camera/gallery
  /// choice + `pickImage` constraints as `PhotosScreen._addPhoto` (profile
  /// photos) — reused for consistency, not re-derived.
  Future<void> _pickAndSendPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;

    setState(() => _sendingPhoto = true);
    try {
      final message = await ref
          .read(chatRepositoryProvider)
          .sendPhoto(widget.conversation.id, file.path);
      if (!mounted) return;
      _appendMessageIfNew(message);
      setState(() => _sendingPhoto = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sendingPhoto = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Composer's single "+" button — docs/07's "attachment button reveals
  /// voice/photo/GIF" menu, now that all three (#16/#17/#18) are built.
  /// Kept as a bottom sheet rather than a popup/dropdown to match the
  /// picker sheets' own presentation (gif picker, photo's camera/gallery
  /// choice) — one consistent "sheet slides up from the bottom" idiom for
  /// every composer-triggered choice in this screen.
  Future<void> _showAttachmentMenu() async {
    final action = await showModalBottomSheet<_AttachmentAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Voice note'),
              onTap: () =>
                  Navigator.pop(sheetContext, _AttachmentAction.voiceNote),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(sheetContext, _AttachmentAction.photo),
            ),
            ListTile(
              leading: const Icon(Icons.gif_box_outlined),
              title: const Text('GIF'),
              onTap: () => Navigator.pop(sheetContext, _AttachmentAction.gif),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _AttachmentAction.voiceNote:
        await _startRecording();
      case _AttachmentAction.photo:
        await _pickAndSendPhoto();
      case _AttachmentAction.gif:
        await _pickAndSendGif();
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
    _callIncomingSub?.cancel();
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

    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final photos = otherUser.photos;

    return Scaffold(
      appBar: AppBar(
        // A hairline under the header separates it from the conversation.
        shape: Border(bottom: BorderSide(color: p.border)),
        titleSpacing: 0,
        title: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: ClipOval(
                child: photos.isEmpty
                    ? const PhotoPlaceholder(iconSize: 22)
                    : NetworkPhoto(photos.first.url),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otherUser.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  if (_otherIsTyping)
                    Text(
                      'Typing…',
                      style: text.labelSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    )
                  else if (isOnline)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 8,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Online', style: text.labelSmall),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Phase 3 items 4/5 — shown unconditionally; the actual active-
          // match/subscriber gate is server-side (CallController), same
          // "the UI never needs to pre-check" discipline as every other
          // premium/entitlement gate in this app. `CallType` here is a
          // `calls` feature type, not this one's — see
          // `_handleIncomingCall`'s doc comment for why `chat` importing
          // from `calls` (not the usual direction) is deliberate.
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Voice call',
            onPressed: () => _startCall(CallType.voice),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video call',
            onPressed: () => _startCall(CallType.video),
          ),
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
        bottom: false,
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            if (_requiresSubscriptionToMessage)
              SubscriptionRequiredBanner(
                onUpgrade: () async {
                  await context.push('/settings/subscription');
                  await _refreshSubscriptionRequirement();
                },
              )
            else if (_recording)
              RecordingBar(
                elapsed: _recordingElapsed,
                onCancel: _cancelRecording,
                onStop: _stopAndSendRecording,
              )
            else
              MessageComposer(
                controller: _composerController,
                sending: _sending,
                attachmentBusy:
                    _sendingVoiceNote || _sendingGif || _sendingPhoto,
                onChanged: _onComposerChanged,
                onSend: _send,
                onAttachment: _showAttachmentMenu,
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
      return StateMessage(
        icon: Icons.error_outline,
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadFirstPage,
      );
    }
    if (_messages.isEmpty) {
      return StateMessage(
        icon: Icons.waving_hand_outlined,
        title: 'You matched!',
        message: 'Say hi to ${widget.conversation.otherUser.displayName}.',
      );
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.md,
      ),
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

        // The list is newest-first: index - 1 is the *newer* neighbour (below
        // on screen), index + 1 the *older* one (above).
        final newer = index > 0 ? _messages[index - 1] : null;
        final older = index + 1 < _messages.length
            ? _messages[index + 1]
            : null;
        final startsRun = older == null || !messagesGroup(message, older);
        final endsRun = newer == null || !messagesGroup(message, newer);
        final startsDay =
            older == null || !isSameDay(older.createdAt, message.createdAt);

        return MessageBubble(
          // The list prepends new messages (`_handleIncomingMessage`/`_send`),
          // which shifts every existing bubble's builder index — a stable key
          // keeps VoiceNotePlayer's per-message AudioPlayer state (and
          // playback position) from getting reassigned to the wrong message
          // across a rebuild.
          key: ValueKey(message.id),
          message: message,
          isMine: isMine,
          showReadReceipt: showReadReceipt,
          showTime: endsRun,
          topGap: startsRun ? AppSpacing.md : 2,
          dateLabel: startsDay ? formatDateSeparator(message.createdAt) : null,
        );
      },
    );
  }
}
