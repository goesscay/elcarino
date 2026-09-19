import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/data/chat_repository.dart';
import '../../chat/domain/conversation.dart';
import '../../core/network/api_exception.dart';
import '../../discovery/domain/candidate.dart';
import '../../profile/data/profile_repository.dart';
import '../data/matching_repository.dart';
import '../domain/swipe_direction.dart';
import 'match_celebration_dialog.dart';

/// Sends one swipe and, on a mutual like, plays the match celebration. The one
/// place that does both, so a like from the Discover deck, from a Likes tile's
/// detail screen and from Explore all behave identically.
///
/// Returns whether the swipe went through. On an [ApiException] it shows the
/// message in a snackbar and returns `false` (the caller keeps the person where
/// they were). Waits for the celebration to be dismissed before returning, so a
/// caller that pops a screen afterwards never pops it out from under the dialog.
Future<bool> submitSwipe({
  required BuildContext context,
  required WidgetRef ref,
  required DiscoveryCandidate candidate,
  required SwipeDirection direction,
}) async {
  try {
    final result = await ref
        .read(matchingRepositoryProvider)
        .swipe(targetId: candidate.id, direction: direction);
    if (result.matched && context.mounted) {
      // The chat to open and the viewer's own photo (for the two-photo
      // celebration) are independent reads — fetch them together.
      final (conversation, myPhotoUrl) = await (
        _findConversation(ref, result.matchId),
        _findMyPhotoUrl(ref),
      ).wait;
      if (!context.mounted) return true;
      await showMatchCelebration(
        context,
        candidate,
        conversation: conversation,
        myPhotoUrl: myPhotoUrl,
      );
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
    return false;
  }
}

/// `SwipeService` (item 6) creates a `Conversation` alongside every
/// `UserMatch` in the same request, so it's already there to look up by the
/// time the swipe response comes back — just an extra `GET
/// /chat/conversations` round-trip so the celebration's "Send a message" button
/// has somewhere real to go.
Future<Conversation?> _findConversation(WidgetRef ref, int? matchId) async {
  if (matchId == null) return null;
  try {
    final conversations = await ref
        .read(chatRepositoryProvider)
        .getConversations();
    for (final conversation in conversations) {
      if (conversation.matchId == matchId) return conversation;
    }
    return null;
  } on ApiException {
    return null;
  }
}

/// The viewer's own primary photo, for the match celebration. Best-effort: a
/// failure just means the celebration shows a placeholder for it rather than
/// delaying or blocking the moment.
Future<String?> _findMyPhotoUrl(WidgetRef ref) async {
  try {
    final profile = await ref.read(profileRepositoryProvider).getProfile();
    final photos = profile?.photos ?? const [];
    return photos.isEmpty ? null : photos.first.url;
  } on ApiException {
    return null;
  }
}
