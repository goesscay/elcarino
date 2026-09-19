import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/tab_refresh.dart';
import '../theme/app_colors.dart';

/// The authenticated app's bottom-tab shell (docs/07 §2.1): Discover, Chats,
/// Profile. Each tab keeps its own navigation stack and state; everything that
/// should feel full-screen (a conversation, a call, edit screens, settings,
/// onboarding) is a top-level route that opens *over* this shell, hiding the
/// bar.
///
/// Explore and Likes are deliberately not tabs yet: neither has a screen or an
/// API behind it (Likes' `GET /who-liked-me` is [PROPOSED] and unbuilt), and a
/// tab that opens an empty placeholder is worse than no tab. They slot in here
/// as two more [NavigationDestination]s + branches when they exist.
class MainShell extends ConsumerWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _chatsIndex = 1;

  void _onSelected(WidgetRef ref, int index) {
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
