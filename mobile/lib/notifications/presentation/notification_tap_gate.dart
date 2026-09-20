import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum NotificationNavMode { push, go }

class NotificationRoute {
  const NotificationRoute(this.path, this.mode);

  final String path;
  final NotificationNavMode mode;
}

/// Pure routing decision for a notification's `data` payload (docs/03's
/// Notifications `type`s) — exposed (not private) so it's directly
/// unit-testable without a real `RemoteMessage`/`BuildContext`. `null` means
/// "leave the app where it is": `subscription`/`verification`/
/// `report_status`/`system` have no screen to open yet (those features
/// don't exist), and a `new_match`/`new_message` missing its
/// `conversation_id` is malformed, not a screen worth guessing.
NotificationRoute? routeForNotificationData(Map<String, dynamic> data) {
  switch (data['type']) {
    case 'new_match':
    case 'new_message':
      final conversationId = int.tryParse(
        (data['conversation_id'] as String?) ?? '',
      );
      return conversationId == null
          ? null
          : NotificationRoute(
              '/chat/$conversationId',
              NotificationNavMode.push,
            );
    case 'like':
      // The Likes tab. The push itself carries no liker identity (docs/03
      // Notifications); the tab shows the count to everyone and the people to
      // subscribers.
      return const NotificationRoute('/likes', NotificationNavMode.go);
    case 'verification':
      // The outcome is on the profile (the badge, or the Get verified card to
      // try again), so that is where the tap lands.
      return const NotificationRoute('/profile', NotificationNavMode.go);
    default:
      return null;
  }
}

/// Wraps the app (via `MaterialApp.router`'s `builder`, see `app.dart`) to
/// wire up push-notification tap handling — Phase 1 item 9's other half
/// beyond delivery itself: foreground display (Android suppresses the
/// system tray while the app is foregrounded, so this shows a SnackBar
/// instead) and tap-to-open deep linking for background/terminated taps.
///
/// No-ops entirely if Firebase never initialized (not configured, or init
/// failed) — see `push_repository.dart`'s `initializeFirebaseIfConfigured`,
/// already called from `main()` before this widget ever builds.
class NotificationTapGate extends StatefulWidget {
  const NotificationTapGate({required this.child, super.key});

  final Widget child;

  @override
  State<NotificationTapGate> createState() => _NotificationTapGateState();
}

class _NotificationTapGateState extends State<NotificationTapGate> {
  @override
  void initState() {
    super.initState();
    if (Firebase.apps.isEmpty) return;

    FirebaseMessaging.onMessage.listen(_showForegroundBanner);
    FirebaseMessaging.onMessageOpenedApp.listen(_openFor);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _openFor(message);
    });
  }

  void _showForegroundBanner(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${notification.title ?? ''}: ${notification.body ?? ''}'.trim(),
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _openFor(message),
        ),
      ),
    );
  }

  void _openFor(RemoteMessage message) {
    if (!mounted) return;
    final route = routeForNotificationData(message.data);
    if (route == null) return;

    switch (route.mode) {
      case NotificationNavMode.push:
        GoRouter.of(context).push(route.path);
      case NotificationNavMode.go:
        GoRouter.of(context).go(route.path);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
