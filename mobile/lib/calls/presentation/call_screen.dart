import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../chat/data/chat_socket_service.dart';
import '../../chat/domain/conversation.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../data/calls_repository.dart';
import '../data/webrtc_call_service.dart';
import '../domain/call.dart';
import '../domain/call_type.dart';

enum _Phase { ringingOutgoing, ringingIncoming, negotiating, active, ended }

/// Phase 3 items 4/5 (voice + video calling, open decisions #19/#20,
/// confirmed WebRTC). One screen for both roles and both call types —
/// [incomingCall] non-null means this device is the callee answering an
/// already-created call (routed here from [ConversationScreen]'s
/// `onCallIncoming` listener); null means this device is the caller,
/// starting a fresh one.
///
/// Signaling ordering (why this isn't just "call `initialize()`
/// immediately on both ends"): the caller's [WebRtcCallService] only starts
/// negotiating once `call.answered` arrives — not the instant `/token`
/// returns — so its offer is never whispered before the callee has even
/// begun listening for one. The callee only starts listening once it's
/// actually answered (`_accept`), not the moment the incoming-call UI
/// appears — prompting for camera/mic access before the user has agreed to
/// take the call would be backwards.
///
/// Scope disclosed, not silently assumed: this screen only exists on the
/// receiving end if `ConversationScreen`'s presence-channel subscription
/// caught the `call.incoming` broadcast — see `CallController`'s doc
/// comment for the full "app must already be on this conversation" caveat.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    required this.conversation,
    required this.type,
    this.incomingCall,
    super.key,
  });

  final Conversation conversation;
  final CallType type;
  final Call? incomingCall;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  ConversationChannel? _channel;
  WebRtcCallService? _service;
  StreamSubscription<Call>? _answeredSub;
  StreamSubscription<Call>? _endedSub;
  StreamSubscription<RTCPeerConnectionState>? _connectionStateSub;
  StreamSubscription<MediaStream>? _remoteStreamSub;

  Call? _call;
  List<IceServer>? _iceServers;
  late _Phase _phase = widget.incomingCall != null
      ? _Phase.ringingIncoming
      : _Phase.ringingOutgoing;
  bool _muted = false;
  String? _error;

  bool get _isVideo => widget.type == CallType.video;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_isVideo) {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
    }
    if (!mounted) return;

    final socketService = ref.read(chatSocketServiceProvider);
    await socketService.connect();
    if (!mounted) return;
    _channel = socketService.joinConversation(widget.conversation.id);

    if (widget.incomingCall != null) {
      _call = widget.incomingCall;
      _listenForEnd();
    } else {
      await _startOutgoing();
    }
  }

  Future<void> _startOutgoing() async {
    try {
      final session = await ref
          .read(callsRepositoryProvider)
          .startCall(widget.conversation.id, widget.type);
      if (!mounted) return;
      setState(() {
        _call = session.call;
        _iceServers = session.iceServers;
      });
      _listenForEnd();
      _answeredSub = _channel!.onCallAnswered
          .where((c) => c.id == _call!.id)
          .listen((_) => _beginNegotiation(isCaller: true));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _accept() async {
    try {
      final session = await ref
          .read(callsRepositoryProvider)
          .answerCall(_call!.id);
      if (!mounted) return;
      _iceServers = session.iceServers;
      await _beginNegotiation(isCaller: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _beginNegotiation({required bool isCaller}) async {
    if (!mounted) return;
    setState(() => _phase = _Phase.negotiating);

    final service = WebRtcCallService(
      callId: _call!.id,
      type: widget.type,
      isCaller: isCaller,
      iceServers: _iceServers!,
      channel: _channel!,
    );
    _service = service;
    _connectionStateSub = service.onConnectionState.listen(
      _handleConnectionState,
    );
    _remoteStreamSub = service.onRemoteStream.listen((stream) {
      if (_isVideo) _remoteRenderer.srcObject = stream;
    });

    await service.initialize();
    if (!mounted) return;
    if (_isVideo) _localRenderer.srcObject = service.localStream;
    setState(() {});
  }

  void _handleConnectionState(RTCPeerConnectionState state) {
    if (!mounted) return;
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
        _phase != _Phase.active) {
      // One rebuild for the phase change itself — the elapsed-time ticker
      // lives in its own small widget (`_ElapsedTimer`) below rather than
      // ticking `setState` on this whole screen every second. It used to:
      // caught live testing between two real emulators that doing so
      // rebuilds (and, evidently, under enough memory pressure — two
      // WebRTC-active emulators at once — re-fetches) the avatar image
      // every single second for the entire call, which was slow enough to
      // start starving the dev server of capacity for other requests
      // (including, at one point, this same call's own end-call request).
      setState(() => _phase = _Phase.active);
    }
  }

  void _listenForEnd() {
    _endedSub = _channel!.onCallEnded.where((c) => c.id == _call!.id).listen((
      call,
    ) {
      if (!mounted) return;
      setState(() {
        _call = call;
        _phase = _Phase.ended;
      });
      _teardownMedia();
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) context.pop();
      });
    });
  }

  Future<void> _decline() async {
    try {
      await ref.read(callsRepositoryProvider).declineCall(_call!.id);
    } on ApiException {
      // Best-effort — the screen is closing regardless.
    }
    if (mounted) context.pop();
  }

  Future<void> _hangUp() async {
    final callId = _call?.id;
    await _teardownMedia();
    if (callId != null) {
      try {
        await ref.read(callsRepositoryProvider).endCall(callId);
      } on ApiException {
        // Best-effort — the screen is closing regardless.
      }
    }
    if (mounted) context.pop();
  }

  Future<void> _teardownMedia() async {
    await _connectionStateSub?.cancel();
    await _remoteStreamSub?.cancel();
    await _service?.dispose();
    _service = null;
  }

  void _toggleMute() {
    _service?.toggleMute();
    setState(() => _muted = _service?.isMuted ?? _muted);
  }

  void _toggleVideo() {
    _service?.toggleVideo();
    setState(() {});
  }

  @override
  void dispose() {
    _answeredSub?.cancel();
    _endedSub?.cancel();
    _connectionStateSub?.cancel();
    _remoteStreamSub?.cancel();
    _service?.dispose();
    if (_isVideo) {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    // Deliberately not `leaveConversation` — ConversationScreen underneath
    // this one on the nav stack still needs the channel.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherUser = widget.conversation.otherUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          child: Stack(
            children: [
              if (_isVideo && _phase == _Phase.active) _buildVideoLayer(),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      const Spacer(),
                      if (!(_isVideo && _phase == _Phase.active)) ...[
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: AppColors.surfaceDark,
                          backgroundImage: otherUser.photos.isEmpty
                              ? null
                              : NetworkImage(otherUser.photos.first.url),
                          child: otherUser.photos.isEmpty
                              ? Text(
                                  otherUser.displayName.isEmpty
                                      ? '?'
                                      : otherUser.displayName[0],
                                  style: const TextStyle(fontSize: 40),
                                )
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          otherUser.displayName,
                          style: const TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      // The one part of this screen that legitimately needs
                      // to redraw every second — isolated into its own
                      // widget precisely so it's the *only* thing that does
                      // (see `_handleConnectionState`'s doc comment).
                      _phase == _Phase.active
                          ? const _ElapsedTimer()
                          : Text(
                              _statusText(),
                              style: const TextStyle(
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const Spacer(),
                      _buildControls(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    return Stack(
      children: [
        Positioned.fill(
          child: RTCVideoView(
            _remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
        Positioned(
          top: AppSpacing.lg,
          right: AppSpacing.lg,
          width: 100,
          height: 140,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: RTCVideoView(
              _localRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        ),
      ],
    );
  }

  /// Not called for [_Phase.active] — see the ticking [_ElapsedTimer] used
  /// in its place at that call site.
  String _statusText() {
    return switch (_phase) {
      _Phase.ringingOutgoing => 'Calling…',
      _Phase.ringingIncoming =>
        '${widget.conversation.otherUser.displayName} is calling…',
      _Phase.negotiating => 'Connecting…',
      _Phase.active => '',
      _Phase.ended =>
        _call?.status.apiValue == 'declined' ? 'Call declined' : 'Call ended',
    };
  }

  Widget _buildControls() {
    if (_phase == _Phase.ringingIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallButton(
            icon: Icons.call_end,
            color: AppColors.danger,
            onPressed: _decline,
          ),
          _CallButton(
            icon: Icons.call,
            color: AppColors.success,
            onPressed: _accept,
          ),
        ],
      );
    }

    if (_phase == _Phase.ended) {
      return const SizedBox(height: 64);
    }

    final showMediaControls =
        _phase == _Phase.active || _phase == _Phase.negotiating;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (showMediaControls)
          _CallButton(
            icon: _muted ? Icons.mic_off : Icons.mic_none,
            color: AppColors.surfaceDark,
            onPressed: _toggleMute,
          ),
        _CallButton(
          icon: Icons.call_end,
          color: AppColors.danger,
          onPressed: _hangUp,
        ),
        if (showMediaControls && _isVideo)
          _CallButton(
            icon: Icons.videocam_off_outlined,
            color: AppColors.surfaceDark,
            onPressed: _toggleVideo,
          ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.all(AppSpacing.lg),
      ),
      icon: Icon(icon, color: AppColors.onPrimary),
    );
  }
}

/// The call-duration display shown once [_Phase.active]. Its own
/// `Timer.periodic` and its own `setState` — ticking once a second rebuilds
/// only this small text widget, not the whole [CallScreen] (and, critically,
/// not the avatar `Image.network` above it — see
/// `_CallScreenState._handleConnectionState`'s doc comment for the real bug
/// that came from not doing this originally).
class _ElapsedTimer extends StatefulWidget {
  const _ElapsedTimer();

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;
    return Text(
      '$minutes:${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(color: AppColors.textSecondaryDark),
    );
  }
}
