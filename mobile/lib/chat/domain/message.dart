import 'message_type.dart';

/// Mirrors the backend's `MessageAttachmentResource` (docs/03
/// "Chat"/message_attachments). Only present on a [Message] whose [type] is
/// [MessageType.voiceNote] this feature (gif/photo attachments — #17/#18 —
/// aren't built).
class MessageAttachment {
  const MessageAttachment({
    required this.url,
    required this.mimeType,
    required this.durationSeconds,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      MessageAttachment(
        url: json['url'] as String,
        mimeType: json['mime_type'] as String,
        durationSeconds: json['duration_seconds'] as int?,
      );

  final String url;
  final String mimeType;
  final int? durationSeconds;
}

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
    required this.attachment,
    required this.readAt,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as int,
    conversationId: json['conversation_id'] as int,
    senderId: json['sender_id'] as int,
    body: json['body'] as String?,
    type: MessageType.fromApiValue(json['type'] as String),
    // `whenLoaded` on an unloaded relation serializes to a MissingValue that
    // Laravel just omits from the JSON entirely — so this key can be either
    // absent or null for a text message, both meaning "no attachment".
    attachment: json['attachment'] == null
        ? null
        : MessageAttachment.fromJson(
            json['attachment'] as Map<String, dynamic>,
          ),
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
  final MessageAttachment? attachment;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  bool sentBy(int userId) => senderId == userId;
}
