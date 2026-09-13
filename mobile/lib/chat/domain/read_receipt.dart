/// The `messages.read` broadcast event's payload (see the backend's
/// `MessagesReadBroadcast`) — tells an open conversation screen whose
/// messages just got marked read, so sent-message ticks can update live.
class ReadReceipt {
  const ReadReceipt({required this.readByUserId, required this.readAt});

  factory ReadReceipt.fromJson(Map<String, dynamic> json) => ReadReceipt(
    readByUserId: json['read_by_user_id'] as int,
    readAt: DateTime.parse(json['read_at'] as String),
  );

  final int readByUserId;
  final DateTime readAt;
}
