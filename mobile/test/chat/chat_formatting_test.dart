import 'package:datingapp/chat/domain/message.dart';
import 'package:datingapp/chat/domain/message_type.dart';
import 'package:datingapp/chat/presentation/chat_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

Message _msg(int senderId, DateTime at) => Message(
  id: 1,
  conversationId: 1,
  senderId: senderId,
  body: 'hi',
  type: MessageType.text,
  attachment: null,
  readAt: null,
  createdAt: at,
);

void main() {
  group('formatMessageTime', () {
    test('pads hour and minute in local time', () {
      expect(formatMessageTime(DateTime(2026, 9, 19, 9, 5)), '09:05');
      expect(formatMessageTime(DateTime(2026, 9, 19, 23, 40)), '23:40');
    });
  });

  group('formatDateSeparator', () {
    final now = DateTime(2026, 9, 19, 15); // a Saturday

    test('today and yesterday', () {
      expect(formatDateSeparator(DateTime(2026, 9, 19, 1), now: now), 'Today');
      expect(
        formatDateSeparator(DateTime(2026, 9, 18, 23), now: now),
        'Yesterday',
      );
    });

    test('a weekday within the past week', () {
      expect(
        formatDateSeparator(DateTime(2026, 9, 15, 12), now: now),
        'Tuesday',
      );
    });

    test('older dates are "Mon D", with the year if not this year', () {
      expect(formatDateSeparator(DateTime(2026, 9, 1), now: now), 'Sep 1');
      expect(
        formatDateSeparator(DateTime(2025, 12, 31), now: now),
        'Dec 31, 2025',
      );
    });
  });

  group('isSameDay', () {
    test('same calendar day, different times', () {
      expect(
        isSameDay(DateTime(2026, 9, 19, 0, 1), DateTime(2026, 9, 19, 23, 59)),
        isTrue,
      );
    });

    test('adjacent days are different', () {
      expect(
        isSameDay(DateTime(2026, 9, 19, 23, 59), DateTime(2026, 9, 20, 0, 1)),
        isFalse,
      );
    });
  });

  group('messagesGroup', () {
    final t = DateTime(2026, 9, 19, 12);

    test('same sender within five minutes groups', () {
      expect(
        messagesGroup(_msg(1, t), _msg(1, t.add(const Duration(minutes: 4)))),
        isTrue,
      );
    });

    test('a different sender never groups', () {
      expect(messagesGroup(_msg(1, t), _msg(2, t)), isFalse);
    });

    test('same sender but five or more minutes apart does not group', () {
      expect(
        messagesGroup(_msg(1, t), _msg(1, t.add(const Duration(minutes: 5)))),
        isFalse,
      );
    });

    test('is symmetric in time order', () {
      final later = t.add(const Duration(minutes: 2));
      expect(messagesGroup(_msg(1, later), _msg(1, t)), isTrue);
    });
  });
}
