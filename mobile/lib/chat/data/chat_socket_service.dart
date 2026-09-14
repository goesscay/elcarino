import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusher_reverb_flutter/pusher_reverb_flutter.dart';

import '../../calls/domain/call.dart';
import '../../calls/domain/call_signal.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import '../domain/message.dart';
import '../domain/read_receipt.dart';

/// Decodes a channel event's `data` payload. Per the Pusher/Reverb wire
/// protocol this arrives as a JSON-encoded string for server-broadcast
/// events, but already-decoded for whispered client events (`Channel
/// .whisper` never string-encodes its payload — see the package source).
/// Exposed (not private) so it's directly unit-testable against both shapes
/// without needing a real socket.
Map<String, dynamic> decodeEventData(dynamic data) {
  if (data is String) {
    return jsonDecode(data) as Map<String, dynamic>;
  }
  if (data is Map<String, dynamic>) {
    return data;
  }
  throw FormatException(
    'Expected a JSON object channel event payload, got ${data.runtimeType}',
  );
}

/// Parses a `message.new` event's payload — see the backend's
/// `NewMessageBroadcast::broadcastWith()`.
Message parseNewMessageEvent(dynamic data) =>
    Message.fromJson(decodeEventData(data)['message'] as Map<String, dynamic>);

/// Parses a `messages.read` event's payload — see the backend's
/// `MessagesReadBroadcast::broadcastWith()`.
ReadReceipt parseMessagesReadEvent(dynamic data) =>
    ReadReceipt.fromJson(decodeEventData(data));

/// Parses a `call.incoming`/`call.answered`/`call.ended` event's payload —
/// all three share the same `{ call: CallResource }` shape (see the
/// backend's `Call*Broadcast::broadcastWith()`).
Call parseCallEvent(dynamic data) =>
    Call.fromJson(decodeEventData(data)['call'] as Map<String, dynamic>);

/// A live connection to one conversation's presence channel — see
/// docs/03-api-specification.md's `presence-conversation.{id}` row. Wraps a
/// [PresenceChannel] so the rest of the app only ever deals in this feature's
/// own domain types, never a raw [ChannelEvent].
///
/// Also carries the calls feature's (Phase 3 items 4/5) signaling — a
/// deliberate cross-feature dependency (`calls` imports from `chat`, not
/// the other way, so this file importing `calls`' domain types is the one
/// exception to that direction), not an accident: docs/03 "Calls"
/// specifically reuses this same channel for WebRTC signaling rather than
/// standing up a second one, so the connection this class already wraps is
/// the right (only) place for it to live too.
class ConversationChannel {
  ConversationChannel(this._channel);

  final PresenceChannel _channel;

  Stream<Message> get onNewMessage =>
      _channel.on('message.new').map((e) => parseNewMessageEvent(e.data));

  Stream<ReadReceipt> get onMessagesRead =>
      _channel.on('messages.read').map((e) => parseMessagesReadEvent(e.data));

  /// Fires whenever the other participant whispers a typing signal. Carries
  /// no payload — the presence channel's own member list is the "who's
  /// online" signal (docs/03); this is just "someone else is typing now".
  Stream<void> get onTyping => _channel.on('client-typing').map((_) {});

  Stream<Call> get onCallIncoming =>
      _channel.on('call.incoming').map((e) => parseCallEvent(e.data));

  Stream<Call> get onCallAnswered =>
      _channel.on('call.answered').map((e) => parseCallEvent(e.data));

  Stream<Call> get onCallEnded =>
      _channel.on('call.ended').map((e) => parseCallEvent(e.data));

  /// The actual WebRTC offer/answer/ICE-candidate exchange — peer-to-peer,
  /// never a REST call, never persisted (docs/03 "Calls"). Reverb never
  /// echoes a whisper back to its own sender, so — same as `onTyping` — no
  /// self-filtering is needed on the receiving end.
  Stream<CallSignal> get onCallSignal => _channel
      .on('client-call-signal')
      .map((e) => CallSignal.fromJson(decodeEventData(e.data)));

  void sendCallSignal(CallSignal signal) =>
      _channel.whisper('call-signal', signal.toJson());

  /// Current online members, keyed by the auth callback's `channel_data` —
  /// `routes/channels.php`'s presence callback returns `{id, name}` per user.
  List<PresenceMember> get onlineMembers => _channel.members;

  /// Whispers a typing signal to the other participant. The Pusher/Reverb
  /// protocol never echoes a client event back to its own sender, so no
  /// self-filtering is needed on the receiving end.
  void sendTyping() => _channel.whisper('typing', const {});
}

/// Wraps the singleton [ReverbClient] (docs/08-environment-setup.md) behind
/// this app's own types. One instance is shared app-wide via
/// [chatSocketServiceProvider] — the socket connection is meant to be
/// long-lived across screens, not reopened per conversation.
class ChatSocketService {
  ChatSocketService(this._tokenStorage);

  final TokenStorage _tokenStorage;
  ReverbClient? _client;

  bool get isConnected => _client?.connectionState == ConnectionState.connected;

  /// Idempotent — safe to call every time chat becomes relevant (e.g. app
  /// resume), without tearing down an existing connection.
  Future<void> connect() async {
    final config = AppConfig.current;
    final client = ReverbClient.instance(
      host: config.reverbHost,
      port: config.reverbPort,
      appKey: config.reverbAppKey,
      useTLS: config.reverbUseTls,
      authEndpoint: config.reverbAuthEndpoint,
      authorizer: _authorize,
    );
    _client = client;

    if (client.connectionState == ConnectionState.connected) {
      return;
    }

    // `client.connect()` itself only resolves once the WebSocket channel is
    // created — well before the Reverb/Pusher handshake (the server's
    // `connection_established` message) actually completes and flips
    // `connectionState` to `connected`. The old version of this method
    // returned as soon as `connect()` did (or even earlier, on an
    // already-`connecting` early return), which races whoever calls us next:
    // `joinConversation()` right after would throw "Cannot subscribe to
    // channel: not connected to server" if the handshake hadn't finished —
    // caught during Phase 3 items 4/5's live two-emulator testing (docs/08),
    // reproducible even on an otherwise-healthy connection under load, not
    // just a genuinely stale one. So: actually wait for the `connected`
    // state (bounded, so a truly broken connection still fails fast instead
    // of hanging `connect()` forever).
    final becameConnected = client.onConnectionStateChange.firstWhere(
      (state) => state == ConnectionState.connected,
    );

    if (client.connectionState != ConnectionState.connecting) {
      await client.connect();
    }

    await becameConnected.timeout(const Duration(seconds: 10));
  }

  /// Injects the Sanctum bearer token into the `POST /api/broadcasting/auth`
  /// request `ReverbClient` makes when subscribing to a private/presence
  /// channel — the same header every other endpoint needs, per
  /// `backend/bootstrap/app.php`'s `withBroadcasting` middleware.
  Future<Map<String, String>> _authorize(
    String channelName,
    String socketId,
  ) async {
    final token = await _tokenStorage.readToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  void disconnect() => _client?.disconnect();

  /// Subscribes to [conversationId]'s presence channel (or returns the
  /// existing subscription if already joined). Must be called after
  /// [connect] has completed.
  ConversationChannel joinConversation(int conversationId) {
    final client = _client;
    if (client == null) {
      throw StateError(
        'ChatSocketService.connect() must complete before joinConversation().',
      );
    }
    final channel = client.subscribeToPresenceChannel(
      'presence-conversation.$conversationId',
    );
    return ConversationChannel(channel);
  }

  /// Leaves [conversationId]'s presence channel — call when the conversation
  /// screen is disposed so the member list (the online/offline signal)
  /// accurately reflects who's still actually looking at it.
  void leaveConversation(int conversationId) {
    _client?.unsubscribeFromChannel('presence-conversation.$conversationId');
  }
}

final chatSocketServiceProvider = Provider<ChatSocketService>(
  (ref) => ChatSocketService(ref.watch(tokenStorageProvider)),
);
