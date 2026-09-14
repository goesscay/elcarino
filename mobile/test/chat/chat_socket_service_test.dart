import 'package:datingapp/chat/data/chat_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// These exercise the pure event-payload parsing that
/// [ConversationChannel] maps onto its typed streams — the part of
/// `ChatSocketService` that's actually feasible to unit test without a real
/// Reverb server. The socket wiring itself (subscribing, whispering) was
/// verified manually against a running `reverb:start`, the same way the
/// backend's synchronous-broadcast round trip was (docs/08).
void main() {
  group('decodeEventData', () {
    test('decodes a JSON-string payload (server-broadcast events)', () {
      final decoded = decodeEventData('{"foo":"bar"}');
      expect(decoded, {'foo': 'bar'});
    });

    test('passes an already-decoded Map through (whispered client events)', () {
      final decoded = decodeEventData({'foo': 'bar'});
      expect(decoded, {'foo': 'bar'});
    });

    test('throws a FormatException for an unexpected payload shape', () {
      expect(() => decodeEventData(42), throwsFormatException);
    });
  });

  group('parseNewMessageEvent', () {
    test('parses a message.new payload into a Message', () {
      final message = parseNewMessageEvent('''
        {"message":{"id":1,"conversation_id":5,"sender_id":9,"body":"hi",
        "type":"text","read_at":null,"created_at":"2026-09-16T00:00:00.000000Z"}}
      ''');

      expect(message.id, 1);
      expect(message.body, 'hi');
    });
  });

  group('parseMessagesReadEvent', () {
    test('parses a messages.read payload into a ReadReceipt', () {
      final receipt = parseMessagesReadEvent(
        '{"read_by_user_id":9,"read_at":"2026-09-16T01:00:00.000000Z"}',
      );

      expect(receipt.readByUserId, 9);
      expect(receipt.readAt, DateTime.parse('2026-09-16T01:00:00.000000Z'));
    });
  });

  group('parseCallEvent', () {
    test('parses a call.incoming/answered/ended payload into a Call — same '
        '{ call: CallResource } shape for all three', () {
      final userJson =
          '{"id":9,"display_name":"Jane","age":28,"bio":null,'
          '"is_verified":true,"photos":[]}';
      final call = parseCallEvent('''
        {"call":{"id":1,"conversation_id":2,"type":"voice","status":"ringing",
        "caller":$userJson,"callee":$userJson,"started_at":null,
        "ended_at":null,"duration_seconds":null}}
      ''');

      expect(call.id, 1);
      expect(call.status.apiValue, 'ringing');
    });
  });
}
