import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import 'registered_device_storage.dart';

/// Initializes Firebase for push notifications (Phase 1 item 9) — called
/// once from `main()`, before `runApp`, so every later Firebase call
/// (`PushRepository`, `NotificationTapGate`) can assume it already ran
/// rather than racing it. No-ops if [AppConfig.isFirebaseConfigured] is
/// false — no Firebase project exists on this machine yet
/// (docs/08-environment-setup.md) — and swallows any init failure the same
/// way, so a bad/unreachable Firebase project degrades exactly like "no
/// project configured" rather than crashing the app at launch.
///
/// Deliberately initialized via `FirebaseOptions` (from [AppConfig]'s
/// dart-defines) rather than `google-services.json` + the Gradle plugin —
/// the plugin fails the *build* outright without that file present, which
/// would block `flutter build apk` for everyone until a real Firebase
/// project exists. This way the app builds and runs regardless; it just
/// can't actually reach FCM without real values.
Future<void> initializeFirebaseIfConfigured() async {
  final config = AppConfig.current;
  if (!config.isFirebaseConfigured || Firebase.apps.isNotEmpty) return;

  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config.firebaseApiKey!,
        appId: config.firebaseAppId!,
        messagingSenderId: config.firebaseMessagingSenderId!,
        projectId: config.firebaseProjectId!,
      ),
    );
  } catch (_) {
    // See doc above — a bad/unreachable project is not a launch-blocking error.
  }
}

/// Everything below degrades gracefully rather than throwing — see
/// [initializeFirebaseIfConfigured]'s doc, and docs/07 §3.1's "denial is
/// fine, app continues" for notification permission generally. A dead FCM
/// token or a flaky registration call shouldn't be any louder than that.
class PushRepository {
  PushRepository(this._client, this._deviceStorage);

  final ApiClient _client;
  final RegisteredDeviceStorage _deviceStorage;

  StreamSubscription<String>? _tokenRefreshSub;

  /// Call once notification permission has been requested (the onboarding
  /// screen, or app start for an already-onboarded user). No-ops if
  /// Firebase never actually initialized (not configured, or init failed).
  Future<void> registerCurrentDevice() async {
    if (Firebase.apps.isEmpty) return;

    try {
      await FirebaseMessaging.instance.requestPermission();

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _register(token);
      }

      // FCM tokens rotate (app reinstall, OS-level cache clear, etc.) —
      // keep the server's copy current for as long as the app is running.
      _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen(
        _register,
      );
    } catch (_) {
      // See class doc.
    }
  }

  /// Call on logout so a signed-out device stops receiving another
  /// account's message previews in its notification tray.
  Future<void> unregisterCurrentDevice() async {
    try {
      final deviceId = await _deviceStorage.readDeviceId();
      if (deviceId == null) return;

      await _client.request('/users/me/devices/$deviceId', method: 'DELETE');
      await _deviceStorage.clear();
    } on ApiException {
      // Best-effort — a device row surviving a logout is a minor cleanup
      // gap, not worth blocking sign-out over.
    }
  }

  Future<void> _register(String fcmToken) async {
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      final response = await _client.request(
        '/users/me/devices',
        method: 'POST',
        data: {'fcm_token': fcmToken, 'platform': platform},
      );
      await _deviceStorage.saveDeviceId(response.data['device']['id'] as int);
    } on ApiException {
      // Swallowed — see class doc.
    }
  }
}

final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => PushRepository(
    ref.watch(apiClientProvider),
    ref.watch(registeredDeviceStorageProvider),
  ),
);
