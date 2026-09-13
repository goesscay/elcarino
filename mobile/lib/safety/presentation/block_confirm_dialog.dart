import 'package:flutter/material.dart';

/// docs/07-ui-ux-design.md §3.7 "Block confirm" — exact copy, including the
/// "blocking also unmatches" behavior called out there (enforced
/// server-side, `SafetyService::block`; not restated here, the dialog
/// itself already tells the user what happens).
Future<bool> showBlockConfirmDialog(
  BuildContext context,
  String displayName,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Block $displayName?'),
      content: const Text(
        "They won't be able to see your profile or message you, and you won't see them.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
