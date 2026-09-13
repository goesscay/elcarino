import 'message_type.dart';

/// Mirrors the backend's `MessageResource` (docs/03-api-specification.md
/// "Chat"). Constructed both from a REST response (`GET/POST
/// /chat/conversations/{id}/messages`) and from the `message.new` broadcast
/// event's payload — same shape either way.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.type,
    required this.readAt,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as int,
    conversationId: json['conversation_id'] as int,
    senderId: json['sender_id'] as int,
    body: json['body'] as String?,
    type: MessageType.fromApiValue(json['type'] as String),
    readAt: json['read_at'] == null
        ? null
        : DateTime.parse(json['read_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final int id;
  final int conversationId;
  final int senderId;
  final String? body;
  final MessageType type;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  bool sentBy(int userId) => senderId == userId;
}
