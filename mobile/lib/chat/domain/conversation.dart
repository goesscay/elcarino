import '../../matching/domain/match.dart';

/// Mirrors the backend's `ConversationResource` (docs/03-api-specification.md
/// "Chat"). One of these exists for every active or historical match — a
/// fresh match with no messages yet has `lastMessageAt == null` and
/// `lastMessagePreview == null`, and still shows up in the inbox per
/// docs/07 §3.3, rather than only appearing once someone sends a first
/// message.
class Conversation {
  const Conversation({
    required this.id,
    required this.matchId,
    required this.otherUser,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.unreadCount,
    required this.requiresSubscriptionToMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as int,
    matchId: json['match_id'] as int?,
    otherUser: MatchedUser.fromJson(json['other_user'] as Map<String, dynamic>),
    lastMessageAt: json['last_message_at'] == null
        ? null
        : DateTime.parse(json['last_message_at'] as String),
    lastMessagePreview: json['last_message_preview'] as String?,
    unreadCount: json['unread_count'] as int,
    requiresSubscriptionToMessage:
        json['requires_subscription_to_message'] as bool,
  );

  final int id;
  final int? matchId;
  final MatchedUser otherUser;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final bool requiresSubscriptionToMessage;

  bool get hasMessages => lastMessageAt != null;
}
