import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/tab_refresh.dart';
import '../theme/app_colors.dart';

/// The authenticated app's bottom-tab shell (docs/07 §2.1): Discover, Likes,
/// Chats, Profile. Each tab keeps its own navigation stack and state; everything that
/// should feel full-screen (a conversation, a call, edit screens, settings,
/// onboarding) is a top-level route that opens *over* this shell, hiding the
/// bar.
///
/// Explore isn't a tab yet — it has no screen or API behind it, and a tab that
/// opens an empty placeholder is worse than no tab. It slots in between
/// Discover and Likes as one more [NavigationDestination] + branch when it does.
class MainShell extends ConsumerWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _likesIndex = 1;
  static const _chatsIndex = 2;

  void _onSelected(WidgetRef ref, int index) {
    if (index == _likesIndex) ref.read(likesTabRefreshProvider.notifier).bump();
    if (index == _chatsIndex) ref.read(chatsTabRefreshProvider.notifier).bump();
    // Tapping the already-selected tab pops that tab back to its root.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.palette.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) => _onSelected(ref, i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.style_outlined),
              selectedIcon: Icon(Icons.style),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Likes',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
