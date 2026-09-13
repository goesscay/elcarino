import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../notifications/data/push_repository.dart';
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

    // Re-registers the FCM token on every app launch, not just once during
    // onboarding — a token can rotate between launches (the in-memory
    // onTokenRefresh listener in PushRepository only covers a rotation
    // while the app process stays alive), and this is also what covers a
    // user who granted the OS permission before Push notifications (item 9)
    // existed. Only if the permission decision was already granted — never
    // prompts on its own, that stays the onboarding screen's job.
    if (state.status == AuthStatus.authenticated &&
        await Permission.notification.isGranted) {
      unawaited(ref.read(pushRepositoryProvider).registerCurrentDevice());
    }
  }

  /// Called once a register/login/OTP-verify call returns a token.
  Future<void> signedIn(String token) async {
    await ref.read(tokenStorageProvider).saveToken(token);
    state = AuthState.authenticated;
  }

  Future<void> signedOut() async {
    // Best-effort, before the token is cleared — DELETE /users/me/devices
    // still needs a bearer token to authenticate. A signed-out device
    // shouldn't keep getting another account's message previews.
    await ref.read(pushRepositoryProvider).unregisterCurrentDevice();
    await ref.read(tokenStorageProvider).clear();
    state = AuthState.unauthenticated;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
