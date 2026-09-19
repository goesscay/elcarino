import 'package:datingapp/notifications/presentation/notification_tap_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('routeForNotificationData (docs/03 Notifications types)', () {
    test('new_match routes to the conversation, pushed not replaced', () {
      final route = routeForNotificationData({
        'type': 'new_match',
        'conversation_id': '7',
      });

      expect(route!.path, '/chat/7');
      expect(route.mode, NotificationNavMode.push);
    });

    test('new_message routes to the same conversation route', () {
      final route = routeForNotificationData({
        'type': 'new_message',
        'conversation_id': '3',
      });

      expect(route!.path, '/chat/3');
    });

    test('like routes to the inbox, replacing not pushed', () {
      final route = routeForNotificationData({'type': 'like'});

      expect(route!.path, '/likes');
      expect(route.mode, NotificationNavMode.go);
    });

    test('a new_match missing conversation_id routes nowhere', () {
      expect(routeForNotificationData({'type': 'new_match'}), isNull);
    });

    test('an unrecognised or not-yet-built type routes nowhere', () {
      expect(routeForNotificationData({'type': 'system'}), isNull);
      expect(routeForNotificationData({'type': 'subscription'}), isNull);
      expect(routeForNotificationData({}), isNull);
    });
  });
}
