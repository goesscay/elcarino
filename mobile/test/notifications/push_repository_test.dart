import 'dart:convert';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/notifications/data/push_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_registered_device_storage.dart';
import '../support/fake_token_storage.dart';

class _FakeAdapter implements HttpClientAdapter {
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
    return ResponseBody.fromString(
      jsonEncode({'message': 'ok'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('PushRepository (docs/03 Devices, Phase 1 item 9)', () {
    // No `Firebase.initializeApp()` call happens anywhere in a plain
    // `flutter test` run, so `Firebase.apps` is always empty here — these
    // exercise the "not configured" no-op path. The real
    // token-acquisition/registration path needs an actual Firebase app and
    // is verified manually once a real project exists (docs/08), same
    // status as the backend's FcmPushSender.
    test('registerCurrentDevice makes no HTTP call when Firebase never initialized', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _FakeAdapter();
      dio.httpClientAdapter = adapter;
      final repository = PushRepository(
        ApiClient(tokenStorage: FakeTokenStorage(), dio: dio),
        FakeRegisteredDeviceStorage(),
      );

      await repository.registerCurrentDevice();

      expect(adapter.lastRequest, isNull);
    });

    test(
      'unregisterCurrentDevice makes no HTTP call when no device is registered',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        final adapter = _FakeAdapter();
        dio.httpClientAdapter = adapter;
        final repository = PushRepository(
          ApiClient(tokenStorage: FakeTokenStorage(), dio: dio),
          FakeRegisteredDeviceStorage(),
        );

        await repository.unregisterCurrentDevice();

        expect(adapter.lastRequest, isNull);
      },
    );

    test(
      'unregisterCurrentDevice deletes the stored device and clears it',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        final adapter = _FakeAdapter();
        dio.httpClientAdapter = adapter;
        final storage = FakeRegisteredDeviceStorage();
        await storage.saveDeviceId(42);
        final repository = PushRepository(
          ApiClient(tokenStorage: FakeTokenStorage(), dio: dio),
          storage,
        );

        await repository.unregisterCurrentDevice();

        expect(adapter.lastRequest!.method, 'DELETE');
        expect(adapter.lastRequest!.path, '/users/me/devices/42');
        expect(await storage.readDeviceId(), isNull);
      },
    );
  });
}
