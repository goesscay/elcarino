import 'package:flutter/material.dart';

/// Placeholder colour tokens — values are provisional (neutral, brand-agnostic)
/// per `docs/07-ui-ux-design.md` §4.1. Swap the *values* once branding lands
/// (open decision #2); keep the token *names*.
///
/// Never hard-code a `Color` in a widget — reference a token here.
abstract final class AppColors {
  // Light
  static const bgLight = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFF5F5F7);
  static const textPrimaryLight = Color(0xFF1B1B1F);
  static const textSecondaryLight = Color(0xFF6B6B72);
  static const borderLight = Color(0xFFE4E4E9);

  // Dark
  static const bgDark = Color(0xFF121317);
  static const surfaceDark = Color(0xFF1E1F24);
  static const textPrimaryDark = Color(0xFFECECEE);
  static const textSecondaryDark = Color(0xFF9A9AA2);
  static const borderDark = Color(0xFF33343A);

  // Brand / semantic (shared across themes for now)
  static const primary = Color(0xFFE4405F); // placeholder
  static const onPrimary = Color(0xFFFFFFFF);
  static const pass = Color(0xFF8A8A8E);
  static const success = Color(0xFF2E9C68);
  static const warning = Color(0xFFD9832A);
  static const danger = Color(0xFFD64545);
}
