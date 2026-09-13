import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists this installation's own `user_devices` row id (returned by
/// `POST /users/me/devices`) so logout can `DELETE` it — mirrors
/// `core/auth/token_storage.dart`'s shape, but scoped to this feature since
/// nothing else needs it.
class RegisteredDeviceStorage {
  RegisteredDeviceStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _deviceIdKey = 'registered_device_id';

  final FlutterSecureStorage _storage;

  Future<int?> readDeviceId() async {
    final raw = await _storage.read(key: _deviceIdKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveDeviceId(int id) =>
      _storage.write(key: _deviceIdKey, value: id.toString());

  Future<void> clear() => _storage.delete(key: _deviceIdKey);
}

final registeredDeviceStorageProvider = Provider<RegisteredDeviceStorage>(
  (ref) => RegisteredDeviceStorage(),
);
