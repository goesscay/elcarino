# Elcarino brand assets

Resolves open decision #2 ([`docs/05-open-decisions.md`](../docs/05-open-decisions.md)).

- **Name:** Elcarino
- **Logo:** [`elcarino-logo.svg`](elcarino-logo.svg) (canonical, vector) /
  [`elcarino-logo.png`](elcarino-logo.png) (flattened, transparent background,
  613×162 @ ~2x). Simple wordmark, bold sans-serif, no icon/flourish — by design,
  in the spirit of Tinder's clean text-only treatment.
- **Colour:** brand red `#DC2626`. Wired into the app as `AppColors.primary`
  ([`mobile/lib/core/theme/app_colors.dart`](../mobile/lib/core/theme/app_colors.dart))
  and `color.primary` in [`docs/07-ui-ux-design.md`](../docs/07-ui-ux-design.md) §4.1.
- **App icon:** a red "E" monogram on white, applied to the Android/iOS/web launcher
  icons already in `/mobile`. It's a placeholder-professional mark generated to unblock
  development — worth revisiting with a designer alongside the rest of the hi-fi visual
  design pass noted in `docs/04-development-phases.md` (Phase 0 gate).
- **Package/bundle id:** `com.mgs.elcarino` (Android `applicationId`/`namespace`, iOS
  `PRODUCT_BUNDLE_IDENTIFIER`).

Not touched: the Dart package name (`name: datingapp` in `mobile/pubspec.yaml`) and the
`package:datingapp/...` import prefix. That's a purely internal Dart identifier with no
user-facing exposure — renaming it means updating every import for zero visible benefit,
so it was deliberately left alone. Flag it if that changes.

## Regenerating the app icon

`mobile`'s launcher icons (Android mipmaps, iOS `AppIcon.appiconset`, web
`icons/Icon-*.png` + `favicon.png`) were generated programmatically (Python + Pillow,
Arial Bold "E" in `#DC2626` on white) rather than hand-designed. If the mark changes,
regenerate the same way or hand these sizes to a designer:

- Android: 48/72/96/144/192 px (`mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`)
- iOS: every size `Assets.xcassets/AppIcon.appiconset/Contents.json` lists, plus the
  1024×1024 marketing icon
- Web: 192/512 px + maskable variants (inset ~15% for the safe zone), 32×32 favicon
