import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// App-wide light/dark themes built from the placeholder tokens in
/// `docs/07-ui-ux-design.md` §4. Typography uses the system default family until a
/// brand typeface is chosen; the size/weight scale is in §4.2.
abstract final class AppTheme {
  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          surface: isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
          error: AppColors.danger,
          outline: isLight ? AppColors.borderLight : AppColors.borderDark,
        );

    final textColor = isLight
        ? AppColors.textPrimaryLight
        : AppColors.textPrimaryDark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? AppColors.bgLight : AppColors.bgDark,
      textTheme: _textTheme(textColor),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outline),
        ),
      ),
    );
  }

  // Scale from docs/07 §4.2. Dynamic type is applied by MediaQuery text scaling.
  static TextTheme _textTheme(Color color) => TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: color,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: color,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: color,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: color,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: color,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: color,
    ),
  );
}
