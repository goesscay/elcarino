import 'dart:convert';

import 'package:datingapp/calls/data/calls_repository.dart';
import 'package:datingapp/calls/domain/call_type.dart';
import 'package:datingapp/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_token_storage.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, Map<String, dynamic>> responses;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final body = responses[options.path] ?? {'message': 'ok'};
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

(CallsRepository, _FakeAdapter) _repositoryReturning(
  Map<String, Map<String, dynamic>> responses,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  final adapter = _FakeAdapter(responses);
  dio.httpClientAdapter = adapter;
  return (
    CallsRepository(ApiClient(tokenStorage: FakeTokenStorage(), dio: dio)),
    adapter,
  );
}

Map<String, dynamic> _userJson(int id) => {
  'id': id,
  'display_name': 'User $id',
  'age': 28,
  'bio': null,
  'is_verified': true,
  'photos': [],
};

Map<String, dynamic> _callJson({String status = 'ringing'}) => {
  'id': 1,
  'conversation_id': 2,
  'type': 'voice',
  'status': status,
  'caller': _userJson(9),
  'callee': _userJson(21),
  'started_at': null,
  'ended_at': null,
  'duration_seconds': null,
};

void main() {
  group('CallsRepository (docs/03 Calls)', () {
    test('startCall posts conversation_id/type and maps the session', () async {
      final (repository, adapter) = _repositoryReturning({
        '/calls/token': {
          'call': _callJson(),
          'ice_servers': [
            {'urls': 'stun:stun.l.google.com:19302'},
          ],
        },
      });

      final session = await repository.startCall(2, CallType.voice);

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.data, {
        'conversation_id': 2,
        'type': 'voice',
      });
      expect(session.call.status.apiValue, 'ringing');
      expect(session.iceServers, hasLength(1));
      expect(session.iceServers.single.urls, 'stun:stun.l.google.com:19302');
    });

    test('answerCall posts to the right path and maps the session', () async {
      final (repository, adapter) = _repositoryReturning({
        '/calls/1/answer': {
          'call': _callJson(status: 'active'),
          'ice_servers': <Map<String, dynamic>>[],
        },
      });

      final session = await repository.answerCall(1);

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/calls/1/answer');
      expect(session.call.status.apiValue, 'active');
    });

    test('declineCall posts to the right path and maps the call', () async {
      final (repository, adapter) = _repositoryReturning({
        '/calls/1/decline': {'call': _callJson(status: 'declined')},
      });

      final call = await repository.declineCall(1);

      expect(adapter.lastRequest!.path, '/calls/1/decline');
      expect(call.status.apiValue, 'declined');
    });

    test('endCall posts to the right path and maps the call', () async {
      final (repository, adapter) = _repositoryReturning({
        '/calls/1/end': {'call': _callJson(status: 'ended')},
      });

      final call = await repository.endCall(1);

      expect(adapter.lastRequest!.path, '/calls/1/end');
      expect(call.status.apiValue, 'ended');
    });
  });
}
