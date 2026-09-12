import 'package:flutter/foundation.dart';

/// A minimal `device_name` value for the auth endpoints (`docs/03` requires
/// one on every token-issuing call). Not real device info — no need to add a
/// package for a value that's only used to label a Sanctum token for the
/// user's own session list later.
String currentDeviceName() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'other',
  };
}
