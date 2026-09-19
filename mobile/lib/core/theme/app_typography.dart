import 'package:flutter/material.dart';

/// The Elcarino type scale — one family (the platform's own: SF on iOS,
/// Roboto on Android; Inter isn't bundled, and a system face keeps the app
/// feeling native on each OS), a strong size hierarchy, and only three
/// weights (400 / 600 / 700) so hierarchy comes from size and weight rather
/// than from many near-identical weights.
///
/// | Role            | Slot            | Size / weight |
/// |-----------------|-----------------|---------------|
/// | Hero            | displaySmall    | 32 / 700      |
/// | Screen title    | headlineMedium  | 28 / 700      |
/// | Section title   | headlineSmall   | 22 / 600      |
/// | Card title      | titleLarge      | 22 / 700      |
/// | List/row title  | titleMedium     | 17 / 600      |
/// | Body            | bodyLarge       | 16 / 400      |
/// | Body (dense)    | bodyMedium      | 15 / 400      |
/// | Secondary       | bodySmall       | 13 / 400      |
/// | Button          | labelLarge      | 16 / 600      |
/// | Chip / label    | labelMedium     | 13 / 600      |
/// | Caption         | labelSmall      | 12 / 400      |
///
/// All sizes scale with the OS dynamic-type setting (docs/07 §4.6).
abstract final class AppTypography {
  static TextTheme textTheme(Color color, Color secondary) => TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.5,
      color: color,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.4,
      color: color,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: -0.2,
      color: color,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.2,
      color: color,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: color,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: color,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: color,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: secondary,
    ),
    labelLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: color,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: color,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),
  );
}
