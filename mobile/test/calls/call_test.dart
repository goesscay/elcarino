import 'package:datingapp/calls/domain/call.dart';
import 'package:datingapp/calls/domain/call_status.dart';
import 'package:datingapp/calls/domain/call_type.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _userJson(int id) => {
  'id': id,
  'display_name': 'User $id',
  'age': 28,
  'bio': null,
  'is_verified': true,
  'photos': [],
};

void main() {
  group('Call.fromJson', () {
    test('parses a ringing call', () {
      final call = Call.fromJson({
        'id': 1,
        'conversation_id': 2,
        'type': 'video',
        'status': 'ringing',
        'caller': _userJson(9),
        'callee': _userJson(21),
        'started_at': null,
        'ended_at': null,
        'duration_seconds': null,
      });

      expect(call.type, CallType.video);
      expect(call.status, CallStatus.ringing);
      expect(call.caller.id, 9);
      expect(call.callee.id, 21);
      expect(call.startedAt, isNull);
      expect(call.isCaller(9), isTrue);
      expect(call.isCaller(21), isFalse);
    });

    test('parses an ended call with timestamps and duration', () {
      final call = Call.fromJson({
        'id': 1,
        'conversation_id': 2,
        'type': 'voice',
        'status': 'ended',
        'caller': _userJson(9),
        'callee': _userJson(21),
        'started_at': '2026-09-16T00:00:00.000000Z',
        'ended_at': '2026-09-16T00:05:00.000000Z',
        'duration_seconds': 300,
      });

      expect(call.status, CallStatus.ended);
      expect(call.startedAt, DateTime.parse('2026-09-16T00:00:00.000000Z'));
      expect(call.durationSeconds, 300);
    });

    // Regression test: caught live during Phase 3 items 4/5 two-emulator
    // verification — Carbon's `diffInSeconds` (backend) returns a float, and
    // PHP's `json_encode` then prints a whole-number float like `60.0`
    // rather than `60`. An `as int?` cast rejects that literal outright
    // (it decodes as a Dart `double`), which crashed both `_hangUp()` (the
    // caller's screen stuck after a successful end-call request) and
    // `_listenForEnd()` (the callee never learning the call had ended) for
    // any call that actually reached `active` — see CallScreen and the
    // backend's own CallController fix.
    test('parses a whole-number-float duration_seconds (60.0, not 60)', () {
      final call = Call.fromJson({
        'id': 1,
        'conversation_id': 2,
        'type': 'voice',
        'status': 'ended',
        'caller': _userJson(9),
        'callee': _userJson(21),
        'started_at': '2026-09-16T00:00:00.000000Z',
        'ended_at': '2026-09-16T00:01:00.000000Z',
        'duration_seconds': 60.0,
      });

      expect(call.durationSeconds, 60);
    });
  });

  group('CallStatus.fromApiValue', () {
    test('maps every backend enum value', () {
      expect(CallStatus.fromApiValue('ringing'), CallStatus.ringing);
      expect(CallStatus.fromApiValue('active'), CallStatus.active);
      expect(CallStatus.fromApiValue('ended'), CallStatus.ended);
      expect(CallStatus.fromApiValue('missed'), CallStatus.missed);
      expect(CallStatus.fromApiValue('declined'), CallStatus.declined);
      expect(CallStatus.fromApiValue('failed'), CallStatus.failed);
    });

    test('falls back to ended for an unrecognised value', () {
      expect(CallStatus.fromApiValue('bogus'), CallStatus.ended);
    });
  });

  group('IceServer', () {
    test('toRtcConfig omits username/credential when absent (STUN)', () {
      const server = IceServer(urls: 'stun:stun.l.google.com:19302');

      expect(server.toRtcConfig(), {'urls': 'stun:stun.l.google.com:19302'});
    });

    test('toRtcConfig includes username/credential when present (TURN)', () {
      const server = IceServer(
        urls: 'turn:relay.example.com:3478',
        username: 'user',
        credential: 'secret',
      );

      expect(server.toRtcConfig(), {
        'urls': 'turn:relay.example.com:3478',
        'username': 'user',
        'credential': 'secret',
      });
    });
  });

  group('CallSession.fromJson', () {
    test('parses the call and ice_servers together', () {
      final session = CallSession.fromJson({
        'call': {
          'id': 1,
          'conversation_id': 2,
          'type': 'voice',
          'status': 'ringing',
          'caller': _userJson(9),
          'callee': _userJson(21),
          'started_at': null,
          'ended_at': null,
          'duration_seconds': null,
        },
        'ice_servers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      });

      expect(session.call.id, 1);
      expect(session.iceServers, hasLength(1));
    });
  });
}
