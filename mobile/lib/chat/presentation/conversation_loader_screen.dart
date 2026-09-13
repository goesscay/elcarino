import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../data/chat_repository.dart';
import '../domain/conversation.dart';
import 'conversation_screen.dart';

/// Resolves a conversation by id and hands off to [ConversationScreen] —
/// for entry points that only have an id, not the full `Conversation`
/// object `/chat/:id`'s normal in-app navigation passes via `extra`
/// (`InboxScreen`, the match-celebration dialog). Right now that's just a
/// tapped push notification (`new_match`/`new_message`, Phase 1 item 9),
/// but any future deep link into a specific conversation faces the same
/// "only have an id" problem this solves generically.
///
/// There's no `GET /chat/conversations/{id}` endpoint (docs/03) — reuses
/// the same "list + find by id" approach already used for the
/// match-celebration dialog's lookup, rather than adding a single-resource
/// endpoint just for this.
class ConversationLoaderScreen extends ConsumerWidget {
  const ConversationLoaderScreen({required this.conversationId, super.key});

  final int conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder(
          future: ref.read(chatRepositoryProvider).getConversations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              final message = snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : 'Something went wrong.';
              return _ErrorState(message: message);
            }

            Conversation? conversation;
            for (final c in snapshot.data!) {
              if (c.id == conversationId) {
                conversation = c;
                break;
              }
            }

            if (conversation == null) {
              return const _ErrorState(
                message: "This conversation isn't available anymore.",
              );
            }

            // Replaces this loading placeholder with the real screen so
            // "back" doesn't return to a blank loader.
            return ConversationScreen(conversation: conversation);
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => context.go('/matches'),
              child: const Text('Go to Matches'),
            ),
          ],
        ),
      ),
    );
  }
}
