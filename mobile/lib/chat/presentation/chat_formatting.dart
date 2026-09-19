import '../domain/message.dart';

/// "12:03" — a message's own time, in the viewer's local time zone.
String formatMessageTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The label on a day divider in a conversation: "Today", "Yesterday", the
/// weekday within the past week, otherwise "Sep 1" (with the year if it isn't
/// this year). [now] is injectable for tests.
String formatDateSeparator(DateTime dateTime, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = dateTime.toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(local.year, local.month, local.day);
  final daysAgo = today.difference(day).inDays;

  if (daysAgo <= 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  if (daysAgo < 7) return _weekdays[local.weekday - 1];
  final label = '${_months[local.month - 1]} ${local.day}';
  return local.year == current.year ? label : '$label, ${local.year}';
}

bool isSameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// Whether two messages belong in the same visual run: sent by the same
/// person within [gap] of each other. A run shares tight spacing, and only its
/// last bubble carries the timestamp and the "tail" corner.
bool messagesGroup(
  Message a,
  Message b, {
  Duration gap = const Duration(minutes: 5),
}) =>
    a.senderId == b.senderId && a.createdAt.difference(b.createdAt).abs() < gap;
