import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../domain/message.dart';
import '../domain/message_type.dart';
import 'chat_formatting.dart';

/// A day divider between runs of messages ("Today", "Yesterday", …).
class DateSeparator extends StatelessWidget {
  const DateSeparator(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

/// One message. Outgoing bubbles are solid brand red with white text;
/// incoming ones are the quiet neutral fill with theme text (so they read in
/// dark mode too). A run of consecutive messages from the same person sits
/// tight; only the last bubble in a run has the small "tail" corner and shows
/// the time — [showTime] — with "Read" appended on the last own message when
/// the other person has read it ([showReadReceipt]).
///
/// [dateLabel], if set, draws a day divider above this message.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    required this.showReadReceipt,
    this.showTime = true,
    this.topGap = AppSpacing.sm,
    this.dateLabel,
    super.key,
  });

  final Message message;
  final bool isMine;
  final bool showReadReceipt;
  final bool showTime;
  final double topGap;
  final String? dateLabel;

  String? _bubbleImageUrl() => switch (message.type) {
    MessageType.gif => message.body,
    MessageType.photo => message.attachment?.url,
    _ => null,
  };

  BorderRadius get _bubbleRadius {
    const big = Radius.circular(20);
    const tail = Radius.circular(6);
    // The corner nearest the sender is tightened on a run's last bubble.
    final tightened = showTime;
    return BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomLeft: isMine || !tightened ? big : tail,
      bottomRight: !isMine || !tightened ? big : tail,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final isMedia =
        message.type == MessageType.gif || message.type == MessageType.photo;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    final meta = [
      if (showTime) formatMessageTime(message.createdAt),
      if (showReadReceipt) 'Read',
    ].join(' · ');

    return Column(
      children: [
        if (dateLabel != null) DateSeparator(dateLabel!),
        Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(top: topGap),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (isMedia)
                  // The image itself is the bubble: no fill or padding, just
                  // the same rounded shape. A gif's url lives in `body`
                  // (ChatController resolves it server-side, no attachment
                  // row); a photo's lives in `attachment.url` (a private,
                  // signed URL — see MessageAttachmentResource).
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth * 0.8),
                    child: ClipRRect(
                      borderRadius: _bubbleRadius,
                      child: _bubbleImageUrl() == null
                          ? const MediaUnavailable()
                          : Image.network(
                              _bubbleImageUrl()!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const MediaUnavailable(),
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : const MediaUnavailable(loading: true),
                            ),
                    ),
                  )
                else
                  Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMine ? AppColors.primary : p.fill,
                      borderRadius: _bubbleRadius,
                    ),
                    child: message.type == MessageType.voiceNote
                        ? (message.attachment == null
                              ? Text(
                                  'Voice note unavailable',
                                  style: text.bodyMedium?.copyWith(
                                    color: isMine
                                        ? AppColors.onPrimary
                                        : p.textPrimary,
                                  ),
                                )
                              : VoiceNotePlayer(
                                  attachment: message.attachment!,
                                  isMine: isMine,
                                ))
                        : Text(
                            message.body ?? '',
                            style: text.bodyLarge?.copyWith(
                              color: isMine
                                  ? AppColors.onPrimary
                                  : p.textPrimary,
                            ),
                          ),
                  ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xs,
                      left: AppSpacing.xs,
                      right: AppSpacing.xs,
                    ),
                    child: Text(meta, style: text.labelSmall),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Placeholder for a gif/photo bubble that has no image url to show
/// (shouldn't happen — ChatController::sendMessage always resolves one
/// before creating the message — but a defensive fallback beats a broken-
/// image icon) or whose image failed to load (an expired/removed Giphy
/// asset — third-party content, no guarantee it stays reachable forever —
/// or a signed URL that expired before the bubble was scrolled back to),
/// and the loading state in between.
class MediaUnavailable extends StatelessWidget {
  const MediaUnavailable({this.loading = false, super.key});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 150,
      height: 100,
      color: p.fill,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.image_not_supported_outlined, color: p.textSecondary),
    );
  }
}

/// The message composer: a "+" for attachments, a soft rounded field, and a
/// send button that's brand red once there's something to send. Behaviour is
/// unchanged — the button is only ever disabled while a send/attachment is in
/// flight — the empty-vs-filled look is purely a visual cue.
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    required this.controller,
    required this.sending,
    required this.attachmentBusy,
    required this.onChanged,
    required this.onSend,
    required this.onAttachment,
    super.key,
  });

  final TextEditingController controller;
  final bool sending;
  final bool attachmentBusy;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttachment;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final busy = sending || attachmentBusy;
    const fieldRadius = BorderRadius.all(Radius.circular(24));
    const noBorder = OutlineInputBorder(
      borderRadius: fieldRadius,
      borderSide: BorderSide.none,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _RoundButton(
                tooltip: 'Attach',
                onPressed: busy ? null : onAttachment,
                background: p.fill,
                child: attachmentBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.add_rounded, color: p.textPrimary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    filled: true,
                    fillColor: p.fill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    border: noBorder,
                    enabledBorder: noBorder,
                    focusedBorder: noBorder,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return _RoundButton(
                    tooltip: 'Send',
                    onPressed: busy ? null : onSend,
                    background: hasText ? AppColors.primary : p.fill,
                    child: sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: hasText
                                  ? AppColors.onPrimary
                                  : p.textSecondary,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            color: hasText
                                ? AppColors.onPrimary
                                : p.textSecondary,
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.onPressed,
    required this.background,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Shown in place of [MessageComposer] while recording — tap the stop button to
/// send, the trash button to discard. Tap-to-start/tap-to-stop, not
/// press-and-hold (see `_ConversationScreenState._startRecording`'s doc).
class RecordingBar extends StatelessWidget {
  const RecordingBar({
    required this.elapsed,
    required this.onCancel,
    required this.onStop,
    super.key,
  });

  final Duration elapsed;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _RoundButton(
                tooltip: 'Discard recording',
                onPressed: onCancel,
                background: p.fill,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Icon(
                Icons.fiber_manual_record,
                color: AppColors.danger,
                size: 12,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Recording… $minutes:${seconds.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              _RoundButton(
                tooltip: 'Send voice note',
                onPressed: onStop,
                background: AppColors.primary,
                child: const Icon(
                  Icons.stop_rounded,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A message bubble's inline voice-note player. Keyed per-message
/// ([MessageBubble]'s key) so its [AudioPlayer] and playback position stay
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
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    required this.attachment,
    required this.isMine,
    super.key,
  });

  final MessageAttachment attachment;
  final bool isMine;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
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
  /// message refetch endpoint).
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
    final p = context.palette;
    final color = widget.isMine ? AppColors.onPrimary : p.textPrimary;
    final total = _duration ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : _position.inMilliseconds / total.inMilliseconds;
    final minutes = total.inMinutes;
    final seconds = total.inSeconds % 60;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: _playing ? 'Pause voice note' : 'Play voice note',
          excludeSemantics: true,
          child: Material(
            color: color.withValues(alpha: 0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggle,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: color,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 96,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              color: color,
              backgroundColor: color.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          '$minutes:${seconds.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
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
class SubscriptionRequiredBanner extends StatelessWidget {
  const SubscriptionRequiredBanner({required this.onUpgrade, super.key});

  final Future<void> Function() onUpgrade;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: p.primaryTint,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                "Subscribe to message people you haven't matched with.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(onPressed: onUpgrade, child: const Text('Upgrade')),
          ],
        ),
      ),
    );
  }
}
