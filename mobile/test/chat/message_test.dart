import 'package:datingapp/chat/domain/message.dart';
import 'package:datingapp/chat/domain/message_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Message.fromJson', () {
    test('parses an unread text message', () {
      final message = Message.fromJson({
        'id': 1,
        'conversation_id': 5,
        'sender_id': 9,
        'body': 'hi',
        'type': 'text',
        'read_at': null,
        'created_at': '2026-09-16T00:00:00.000000Z',
      });

      expect(message.type, MessageType.text);
      expect(message.isRead, isFalse);
      expect(message.sentBy(9), isTrue);
      expect(message.sentBy(1), isFalse);
    });

    test('parses a read message with a read_at timestamp', () {
      final message = Message.fromJson({
        'id': 1,
        'conversation_id': 5,
        'sender_id': 9,
        'body': 'hi',
        'type': 'text',
        'read_at': '2026-09-16T01:00:00.000000Z',
        'created_at': '2026-09-16T00:00:00.000000Z',
      });

      expect(message.isRead, isTrue);
      expect(message.readAt, DateTime.parse('2026-09-16T01:00:00.000000Z'));
    });
  });

  group('MessageType.fromApiValue', () {
    test('maps every backend enum value', () {
      expect(MessageType.fromApiValue('text'), MessageType.text);
      expect(MessageType.fromApiValue('voice_note'), MessageType.voiceNote);
      expect(MessageType.fromApiValue('gif'), MessageType.gif);
      expect(MessageType.fromApiValue('photo'), MessageType.photo);
    });

    test('falls back to text for an unrecognised value', () {
      expect(MessageType.fromApiValue('sticker'), MessageType.text);
    });
  });
}
