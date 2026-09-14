import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../domain/call.dart';
import '../domain/call_type.dart';

/// Calls `/api/v1/calls` (docs/03-api-specification.md "Calls"). The actual
/// WebRTC signaling never goes through here — see
/// `chat/data/chat_socket_service.dart`'s `ConversationChannel` call-related
/// streams/whisper for that; this is REST only: lifecycle transitions.
class CallsRepository {
  CallsRepository(this._client);

  final ApiClient _client;

  /// The **caller** starts a call. 403 `active_match_required` /
  /// `subscription_required` surface as the same typed `ApiException`
  /// every other gated endpoint does.
  Future<CallSession> startCall(int conversationId, CallType type) async {
    final response = await _client.request(
      '/calls/token',
      method: 'POST',
      data: {'conversation_id': conversationId, 'type': type.apiValue},
    );
    return CallSession.fromJson(response.data as Map<String, dynamic>);
  }

  /// The **callee** answers — never call `startCall` on the receiving end,
  /// that would create a second, separate call.
  Future<CallSession> answerCall(int callId) async {
    final response = await _client.request(
      '/calls/$callId/answer',
      method: 'POST',
    );
    return CallSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Call> declineCall(int callId) async {
    final response = await _client.request(
      '/calls/$callId/decline',
      method: 'POST',
    );
    return Call.fromJson(response.data['call'] as Map<String, dynamic>);
  }

  /// Idempotent server-side — safe to call even if the other participant's
  /// own hang-up already ended it.
  Future<Call> endCall(int callId) async {
    final response = await _client.request(
      '/calls/$callId/end',
      method: 'POST',
    );
    return Call.fromJson(response.data['call'] as Map<String, dynamic>);
  }
}

final callsRepositoryProvider = Provider<CallsRepository>(
  (ref) => CallsRepository(ref.watch(apiClientProvider)),
);
