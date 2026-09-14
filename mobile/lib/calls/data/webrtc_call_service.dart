import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../chat/data/chat_socket_service.dart';
import '../domain/call.dart';
import '../domain/call_signal.dart';
import '../domain/call_type.dart';

/// Wraps one call's `RTCPeerConnection` lifecycle — media capture, offer/
/// answer/ICE-candidate exchange (via the [ConversationChannel] passed in,
/// see its own doc comment for why calls piggyback on chat's channel),
/// connection-state, and mute/camera controls. One instance per call, torn
/// down (`dispose`) when it ends.
///
/// Signaling flow: the caller's [initialize] creates and sends an `offer`;
/// the callee's [initialize] just sets up local media and *waits* — its
/// offer arrives via [handleSignal] once the REST `/answer` call has
/// already flipped the call to `active` server-side (`CallScreen`'s job,
/// not this class's), at which point it creates and sends an `answer`.
/// Either side's [handleSignal] also takes `ice-candidate` messages the
/// whole time.
class WebRtcCallService {
  // Not `required this._channel` (the lint's own suggestion) — a private-
  // named parameter can't be passed by name from another file, which would
  // force every call site onto positional args instead; keeping a public
  // `channel` param name and assigning it to the private field explicitly
  // is the more usable shape.
  WebRtcCallService({
    required this.callId,
    required this.type,
    required this.isCaller,
    required this.iceServers,
    required ConversationChannel channel,
  }) : _channel = channel;

  final int callId;
  final CallType type;
  final bool isCaller;
  final List<IceServer> iceServers;
  final ConversationChannel _channel;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription<CallSignal>? _signalSub;

  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  final _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();

  Stream<MediaStream> get onRemoteStream => _remoteStreamController.stream;

  Stream<RTCPeerConnectionState> get onConnectionState =>
      _connectionStateController.stream;

  MediaStream? get localStream => _localStream;

  bool _muted = false;
  bool get isMuted => _muted;

  bool _videoEnabled = true;
  bool get isVideoEnabled => _videoEnabled;

  Future<void> initialize() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': type == CallType.video ? {'facingMode': 'user'} : false,
    });

    final pc = await createPeerConnection({
      'iceServers': iceServers.map((s) => s.toRtcConfig()).toList(),
    });
    _peerConnection = pc;

    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreamController.add(event.streams.first);
      }
    };
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _channel.sendCallSignal(
        CallSignal(
          callId: callId,
          type: 'ice-candidate',
          payload: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        ),
      );
    };
    pc.onConnectionState = (state) {
      _connectionStateController.add(state);
    };

    _signalSub = _channel.onCallSignal
        .where((signal) => signal.callId == callId)
        .listen(handleSignal);

    if (isCaller) {
      final offer = await pc.createOffer(
        type == CallType.video ? {'offerToReceiveVideo': true} : {},
      );
      await pc.setLocalDescription(offer);
      _channel.sendCallSignal(
        CallSignal(
          callId: callId,
          type: 'offer',
          payload: {'sdp': offer.sdp, 'type': offer.type},
        ),
      );
    }
  }

  Future<void> handleSignal(CallSignal signal) async {
    final pc = _peerConnection;
    if (pc == null) return;

    switch (signal.type) {
      case 'offer':
        await pc.setRemoteDescription(
          RTCSessionDescription(
            signal.payload['sdp'] as String,
            signal.payload['type'] as String,
          ),
        );
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        _channel.sendCallSignal(
          CallSignal(
            callId: callId,
            type: 'answer',
            payload: {'sdp': answer.sdp, 'type': answer.type},
          ),
        );
      case 'answer':
        await pc.setRemoteDescription(
          RTCSessionDescription(
            signal.payload['sdp'] as String,
            signal.payload['type'] as String,
          ),
        );
      case 'ice-candidate':
        await pc.addCandidate(
          RTCIceCandidate(
            signal.payload['candidate'] as String?,
            signal.payload['sdpMid'] as String?,
            signal.payload['sdpMLineIndex'] as int?,
          ),
        );
    }
  }

  void toggleMute() {
    _muted = !_muted;
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !_muted;
    }
  }

  void toggleVideo() {
    _videoEnabled = !_videoEnabled;
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = _videoEnabled;
    }
  }

  Future<void> switchCamera() async {
    final videoTracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
    }
  }

  Future<void> dispose() async {
    await _signalSub?.cancel();
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    await _remoteStreamController.close();
    await _connectionStateController.close();
  }
}
