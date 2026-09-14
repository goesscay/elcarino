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

    test('parses a voice note message with its attachment', () {
      final message = Message.fromJson({
        'id': 2,
        'conversation_id': 5,
        'sender_id': 9,
        'body': null,
        'type': 'voice_note',
        'attachment': {
          'url': 'https://cdn.test/voice-notes/1/a.m4a?signature=abc',
          'mime_type': 'audio/mp4',
          'duration_seconds': 12,
        },
        'read_at': null,
        'created_at': '2026-09-16T00:00:00.000000Z',
      });

      expect(message.type, MessageType.voiceNote);
      expect(message.body, isNull);
      expect(message.attachment, isNotNull);
      expect(message.attachment!.mimeType, 'audio/mp4');
      expect(message.attachment!.durationSeconds, 12);
    });

    test('a text message has no attachment whether the key is absent or null', () {
      final withoutKey = Message.fromJson({
        'id': 1,
        'conversation_id': 5,
        'sender_id': 9,
        'body': 'hi',
        'type': 'text',
        'read_at': null,
        'created_at': '2026-09-16T00:00:00.000000Z',
      });
      final withNullKey = Message.fromJson({
        'id': 1,
        'conversation_id': 5,
        'sender_id': 9,
        'body': 'hi',
        'type': 'text',
        'attachment': null,
        'read_at': null,
        'created_at': '2026-09-16T00:00:00.000000Z',
      });

      expect(withoutKey.attachment, isNull);
      expect(withNullKey.attachment, isNull);
    });

    test('parses a gif message (body holds the url directly)', () {
      final message = Message.fromJson({
        'id': 3,
        'conversation_id': 5,
        'sender_id': 9,
        'body': 'https://media.giphy.com/abc/full.gif',
        'type': 'gif',
        'read_at': null,
        'created_at': '2026-09-16T00:00:00.000000Z',
      });

      expect(message.type, MessageType.gif);
      expect(message.body, 'https://media.giphy.com/abc/full.gif');
      expect(message.attachment, isNull);
    });

    test('parses a photo message with its attachment', () {
      final message = Message.fromJson({
        'id': 4,
        'conversation_id': 5,
        'sender_id': 9,
        'body': null,
        'type': 'photo',
        'attachment': {
          'url': 'https://cdn.test/chat-photos/1/a.jpg?signature=abc',
          'mime_type': 'image/jpeg',
          'duration_seconds': null,
        },
        'read_at': null,
        'created_at': '2026-09-16T00:00:00.000000Z',
      });

      expect(message.type, MessageType.photo);
      expect(message.body, isNull);
      expect(message.attachment, isNotNull);
      expect(message.attachment!.mimeType, 'image/jpeg');
      expect(message.attachment!.durationSeconds, isNull);
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
