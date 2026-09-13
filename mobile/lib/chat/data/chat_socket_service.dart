import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusher_reverb_flutter/pusher_reverb_flutter.dart';

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

/// A live connection to one conversation's presence channel — see
/// docs/03-api-specification.md's `presence-conversation.{id}` row. Wraps a
/// [PresenceChannel] so the rest of the app only ever deals in this feature's
/// own domain types, never a raw [ChannelEvent].
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
    if (client.connectionState == ConnectionState.connected ||
        client.connectionState == ConnectionState.connecting) {
      return;
    }
    await client.connect();
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
