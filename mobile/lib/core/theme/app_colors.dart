import 'package:flutter/material.dart';

/// Colour tokens per `docs/07-ui-ux-design.md` §4.1. `primary` is the confirmed
/// Elcarino brand red (open decision #2 — see `/branding`).
///
/// Proportion the palette is built for: ~70% neutral, ~20% white surface,
/// ~10% brand red. Red marks the important action (like, send, the primary
/// CTA, the selected tab), never large fills — the user's photos are the
/// most visually important thing on any screen.
///
/// Never hard-code a `Color` in a widget — reference a token here, or read a
/// brightness-aware one through `context.palette` (see [AppPalette]).
abstract final class AppColors {
  // Light
  static const bgLight = Color(0xFFFAFAFA);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF111111);
  static const textSecondaryLight = Color(0xFF6B6B6B);
  static const borderLight = Color(0xFFE5E5E5);

  /// A quiet neutral fill *on* [bgLight]/[surfaceLight] — chip backgrounds,
  /// an incoming chat bubble, an input field. [surfaceLight] is now pure
  /// white, so it can no longer double as this.
  static const fillLight = Color(0xFFF1F1F3);

  // Dark
  static const bgDark = Color(0xFF111111);
  static const surfaceDark = Color(0xFF1C1C1E);
  static const textPrimaryDark = Color(0xFFFFFFFF);
  static const textSecondaryDark = Color(0xFFA1A1AA);
  static const borderDark = Color(0xFF2C2C2E);
  static const fillDark = Color(0xFF2A2A2D);

  // Brand
  // The brand red IS the logo's red: `#D81D1F`, sampled from the supplied logo file, so
  // buttons and highlights match the logo exactly (it was `#DC2626` until then; decision
  // #2). A test checks it against the logo asset's pixels. It is also the splash's
  // full-bleed background. White text on it is 5.1:1 (WCAG AA).
  static const primary = Color(0xFFD81D1F);
  // The same hue and saturation, a step darker (the old pair's lightness gap).
  static const primaryDark = Color(0xFFB0181A); // pressed / on-light emphasis
  static const primaryLight = Color(0xFFFEE2E2); // tinted fills on light
  static const primaryTintDark = Color(0xFF3B1414); // tinted fills on dark
  static const onPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const pass = Color(0xFF8A8A8E);
  static const success = Color(0xFF2E9C68);
  static const warning = Color(0xFFD9832A);
  static const danger = Color(0xFFD64545);

  // Over-photo. Text and controls that sit on a user's photo are white
  // whatever the app theme (a photo isn't themed); these keep that one
  // deliberate exception in the token file rather than as `Colors.white`
  // scattered through widgets.
  static const onPhoto = Color(0xFFFFFFFF);
  static const onPhotoMuted = Color(0xE6FFFFFF); // secondary text on a photo
  static const onPhotoFaint = Color(0x3DFFFFFF); // placeholder fill on a scrim
  static const photoScrimClear = Color(0x00000000); // gradient start (clear)
  static const photoScrim = Color(0xD9000000); // bottom-of-card gradient end
  static const photoControl = Color(0x73000000); // small control on a photo
  static const modalBarrier = Color(0xE6000000); // full-screen celebration

  /// The soft lift under the large photo card — the one place a shadow is
  /// used; everything else separates by hairline border.
  static const cardShadow = Color(0x1F000000);
}

/// The brightness-aware half of the palette, as a [ThemeExtension] so a
/// widget writes `context.palette.fill` instead of choosing a `…Light` or
/// `…Dark` constant itself (which is how a light chat bubble ended up in dark
/// mode). [AppTheme] registers both instances.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.fill,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.primaryTint,
  });

  static const light = AppPalette(
    background: AppColors.bgLight,
    surface: AppColors.surfaceLight,
    fill: AppColors.fillLight,
    border: AppColors.borderLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    primaryTint: AppColors.primaryLight,
  );

  static const dark = AppPalette(
    background: AppColors.bgDark,
    surface: AppColors.surfaceDark,
    fill: AppColors.fillDark,
    border: AppColors.borderDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    primaryTint: AppColors.primaryTintDark,
  );

  final Color background;
  final Color surface;
  final Color fill;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color primaryTint;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? fill,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? primaryTint,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    fill: fill ?? this.fill,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    primaryTint: primaryTint ?? this.primaryTint,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The current theme's [AppPalette]. Always registered by [AppTheme].
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
