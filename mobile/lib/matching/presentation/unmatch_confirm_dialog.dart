import 'package:flutter/material.dart';

/// Shared "Unmatch `<name>`?" confirm dialog — used by both `InboxScreen`
/// (item 6) and `ConversationScreen`'s header overflow (item 10), so the
/// copy only lives in one place.
Future<bool> showUnmatchConfirmDialog(
  BuildContext context,
  String displayName,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Unmatch $displayName?'),
      content: const Text("You won't see each other again in Discover."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Unmatch'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
