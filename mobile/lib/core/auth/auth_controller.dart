import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState(this.status);

  final AuthStatus status;

  static const unknown = AuthState(AuthStatus.unknown);
  static const authenticated = AuthState(AuthStatus.authenticated);
  static const unauthenticated = AuthState(AuthStatus.unauthenticated);
}

/// App-wide "are we logged in" state — lives in `core/` per
/// `docs/01-technical-specification.md` §4 ("core/ holds shared providers:
/// API client, auth state, config"). The authentication *feature* owns how a
/// session is obtained (register/login/OTP screens + repository); this only
/// tracks the resulting yes/no and persists the token.
///
/// Deliberately holds no user data — the API is the source of truth for
/// profile/onboarding state, fetched fresh where it's needed.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _bootstrap();
    return AuthState.unknown;
  }

  Future<void> _bootstrap() async {
    final token = await ref.read(tokenStorageProvider).readToken();
    state = token != null ? AuthState.authenticated : AuthState.unauthenticated;
  }

  /// Called once a register/login/OTP-verify call returns a token.
  Future<void> signedIn(String token) async {
    await ref.read(tokenStorageProvider).saveToken(token);
    state = AuthState.authenticated;
  }

  Future<void> signedOut() async {
    await ref.read(tokenStorageProvider).clear();
    state = AuthState.unauthenticated;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
