import 'package:datingapp/core/auth/token_storage.dart';

/// An in-memory [TokenStorage] for tests — avoids touching the real
/// `flutter_secure_storage` platform channel, which doesn't exist outside a
/// running app.
class FakeTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
