/// Spacing scale, per the Elcarino redesign brief: 8 · 12 · 16 · 20 · 24 · 32
/// · 40 (with a 4 for hairline gaps). Use these — don't introduce one-off
/// paddings on a screen; consistent rhythm between screens is most of what
/// makes the app feel designed rather than assembled.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Default horizontal screen padding.
  static const screen = 20.0;

  /// Large section breaks / hero spacing.
  static const huge = 40.0;
}

/// Corner radii. Not everything is a pill: small 8, medium 12, large 16,
/// cards 20–24 (profile cards 24), buttons 14–18. Rounding is a hierarchy —
/// when every element is maximally round, none of them read as special.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;

  /// General cards, sheets.
  static const card = 20.0;

  /// The large photo-first profile card (Discover, profile details).
  static const profileCard = 24.0;

  /// Primary/secondary buttons.
  static const button = 16.0;

  /// Truly round things only: avatars, circular action buttons, small chips.
  static const pill = 999.0;
}
