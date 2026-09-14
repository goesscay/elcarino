/// A single WebRTC signaling message — SDP offer/answer or an ICE
/// candidate — whispered peer-to-peer over the conversation's presence
/// channel (`client-call-signal`, docs/03 "Calls"). Never sent through a
/// REST endpoint, never persisted server-side.
class CallSignal {
  const CallSignal({
    required this.callId,
    required this.type,
    required this.payload,
  });

  factory CallSignal.fromJson(Map<String, dynamic> json) => CallSignal(
    callId: json['call_id'] as int,
    type: json['type'] as String,
    payload: json['payload'] as Map<String, dynamic>,
  );

  /// One of `offer` / `answer` / `ice-candidate`.
  final int callId;
  final String type;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'call_id': callId,
    'type': type,
    'payload': payload,
  };
}
