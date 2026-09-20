import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped each time the user selects the Chats tab. The tab shell keeps every
/// tab's screen alive (so Discover keeps its card deck and Profile its scroll
/// position when you switch away and back), which means the inbox no longer
/// gets rebuilt — and so re-fetched — every time it's opened, the way it did
/// when it was a pushed route. [InboxScreen] listens to this and reloads, so a
/// match made in Discover or a message that arrived while on another tab is
/// there when you come back.
class ChatsTabRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final chatsTabRefreshProvider = NotifierProvider<ChatsTabRefresh, int>(
  ChatsTabRefresh.new,
);

/// Same idea for the Likes tab: a like that arrived (or a subscription bought)
/// while on another tab is there when you come back.
class LikesTabRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final likesTabRefreshProvider = NotifierProvider<LikesTabRefresh, int>(
  LikesTabRefresh.new,
);

/// And for Explore: its member counts move as you swipe, so they're refreshed
/// whenever the tab is (re)selected.
class ExploreTabRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final exploreTabRefreshProvider = NotifierProvider<ExploreTabRefresh, int>(
  ExploreTabRefresh.new,
);
