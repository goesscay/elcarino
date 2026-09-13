import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../chat/domain/conversation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../discovery/domain/candidate.dart';

/// docs/07-ui-ux-design.md §3.2 "Match celebration": "Full-screen modal on
/// mutual like: both photos, 'It's a match!', Send a message / Keep
/// swiping." Only shows the *other* person's photo (the viewer's own isn't
/// available on this screen without an extra fetch) — a scoped-down version
/// of "both photos", not the full spec.
///
/// [conversation] is the `Conversation` the caller already resolved for this
/// match (Chat, item 8) — passed in rather than looked up here so this
/// dialog stays pure UI with no repository dependency of its own. `null` is
/// a defensive fallback (`SwipeService` always creates a `Conversation`
/// alongside every `UserMatch`, so this shouldn't normally happen) that
/// falls back to a coming-soon notice instead of a dead navigation, same
/// pattern as the Google/Apple sign-in buttons.
Future<void> showMatchCelebration(
  BuildContext context,
  DiscoveryCandidate matchedWith, {
  Conversation? conversation,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, color: AppColors.primary, size: 72),
              const SizedBox(height: AppSpacing.md),
              const Text(
                "It's a match!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You and ${matchedWith.displayName} liked each other.',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: matchedWith.photos.isEmpty
                    ? Container(width: 160, height: 160, color: Colors.white24)
                    : Image.network(
                        matchedWith.photos.first.url,
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (conversation != null) {
                    context.push(
                      '/chat/${conversation.id}',
                      extra: conversation,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Couldn't open the chat — try it from Matches.",
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Send a message'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Keep swiping',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
