import 'package:datingapp/notifications/data/registered_device_storage.dart';

/// An in-memory [RegisteredDeviceStorage] for tests — avoids touching the
/// real `flutter_secure_storage` platform channel, same reason
/// `FakeTokenStorage` exists for `TokenStorage`.
class FakeRegisteredDeviceStorage extends RegisteredDeviceStorage {
  int? _deviceId;

  @override
  Future<int?> readDeviceId() async => _deviceId;

  @override
  Future<void> saveDeviceId(int id) async => _deviceId = id;

  @override
  Future<void> clear() async => _deviceId = null;
}
