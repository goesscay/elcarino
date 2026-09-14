import '../../matching/domain/match.dart';
import 'call_status.dart';
import 'call_type.dart';

/// Mirrors the backend's `CallResource` (docs/03-api-specification.md
/// "Calls").
class Call {
  const Call({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.status,
    required this.caller,
    required this.callee,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });

  factory Call.fromJson(Map<String, dynamic> json) => Call(
    id: json['id'] as int,
    conversationId: json['conversation_id'] as int,
    type: CallType.fromApiValue(json['type'] as String),
    status: CallStatus.fromApiValue(json['status'] as String),
    caller: MatchedUser.fromJson(json['caller'] as Map<String, dynamic>),
    callee: MatchedUser.fromJson(json['callee'] as Map<String, dynamic>),
    startedAt: json['started_at'] == null
        ? null
        : DateTime.parse(json['started_at'] as String),
    endedAt: json['ended_at'] == null
        ? null
        : DateTime.parse(json['ended_at'] as String),
    // `num?` not `int?` — Carbon's `diffInSeconds` (backend) can compute a
    // float, and PHP's `json_encode` then prints a whole-number float like
    // `60.0` rather than `60`; Dart's `as int?` rejects that literal (it
    // decodes as a `double`), which threw an uncaught exception out of the
    // `call.ended` broadcast listener and the direct `/end` response alike —
    // caught live: it silently killed both `_hangUp()` (stuck on the caller
    // screen after a successful end-call request) and `_listenForEnd()`
    // (the callee never seeing the call end at all) for any call that
    // actually reached `active` (only an active call gets a computed
    // duration; ringing/declined ones stay `null` and never hit this).
    durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
  );

  final int id;
  final int conversationId;
  final CallType type;
  final CallStatus status;
  final MatchedUser caller;
  final MatchedUser callee;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  bool isCaller(int userId) => caller.id == userId;
}

/// One entry of the `RTCIceServer[]`-shaped `ice_servers` array `POST
/// /calls/token` and `/{id}/answer` both return — passed straight through
/// to `flutter_webrtc`'s `RTCPeerConnection` configuration.
class IceServer {
  const IceServer({required this.urls, this.username, this.credential});

  factory IceServer.fromJson(Map<String, dynamic> json) => IceServer(
    urls: json['urls'] as String,
    username: json['username'] as String?,
    credential: json['credential'] as String?,
  );

  final String urls;
  final String? username;
  final String? credential;

  Map<String, dynamic> toRtcConfig() => {
    'urls': urls,
    if (username != null) 'username': username,
    if (credential != null) 'credential': credential,
  };
}

/// `POST /calls/token` and `/{id}/answer` both return this same shape.
class CallSession {
  const CallSession({required this.call, required this.iceServers});

  factory CallSession.fromJson(Map<String, dynamic> json) => CallSession(
    call: Call.fromJson(json['call'] as Map<String, dynamic>),
    iceServers: (json['ice_servers'] as List<dynamic>)
        .map((e) => IceServer.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final Call call;
  final List<IceServer> iceServers;
}
