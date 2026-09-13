import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class AuthResult {
  const AuthResult({required this.token});

  final String token;
}

/// Calls the `/api/v1/auth/*` endpoints (docs/03-api-specification.md). Every
/// call returns just the token — the API is the source of truth for the user
/// record itself, fetched separately where needed (`GET /users/me`).
class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<AuthResult> register({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final response = await _client.request(
      '/auth/register',
      method: 'POST',
      data: {'email': email, 'password': password, 'device_name': deviceName},
    );
    return AuthResult(token: response.data['token'] as String);
  }

  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final response = await _client.request(
      '/auth/login',
      method: 'POST',
      data: {'email': email, 'password': password, 'device_name': deviceName},
    );
    return AuthResult(token: response.data['token'] as String);
  }

  Future<void> requestOtp({required String phone}) async {
    await _client.request(
      '/auth/otp/request',
      method: 'POST',
      data: {'phone': phone},
    );
  }

  /// Passwordless — verifying the first code for a phone number both signs
  /// in and creates the account (backend `AuthController::verifyOtp`), so
  /// there's no separate register/login branch for the phone path.
  Future<AuthResult> verifyOtp({
    required String phone,
    required String code,
    required String deviceName,
  }) async {
    final response = await _client.request(
      '/auth/otp/verify',
      method: 'POST',
      data: {'phone': phone, 'code': code, 'device_name': deviceName},
    );
    return AuthResult(token: response.data['token'] as String);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
