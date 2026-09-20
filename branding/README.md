# Elcarino brand assets

Resolves open decision #2 ([`docs/05-open-decisions.md`](../docs/05-open-decisions.md)).

- **Name:** Elcarino
- **Logo:** the client-supplied "elcarino" wordmark: a bold rounded red lowercase wordmark
  whose "e" holds a white heart, with two small hearts above it.
  - [`elcarino-logo-source.png`](elcarino-logo-source.png): **the logo exactly as supplied**
    (2000×737, opaque white background), converted to PNG losslessly and otherwise untouched.
    This is the source of truth.
  - [`elcarino-logo.png`](elcarino-logo.png): the artwork prepared for use in the app
    (1564×391, **transparent background**). It differs from the source in two mechanical ways
    only: the empty margin is trimmed, and the white background is made transparent (colour to
    alpha, so edges stay smooth and the logo's own red is kept). No redrawing, no recolouring.
    Transparent because the app has a dark mode. Regenerate it with
    [`prepare_logo.py`](prepare_logo.py); the app's copy
    ([`mobile/assets/branding/elcarino-logo.png`](../mobile/assets/branding/elcarino-logo.png))
    is a byte-for-byte copy of it.
  - **No vector version exists.** The supplied file is a raster (a slightly lossy one), so the
    old `elcarino-logo.svg` was removed rather than left behind as a "canonical" file for a
    logo that no longer exists. A designer-supplied SVG would be better for print, app-store
    artwork and very large sizes.
  - On a dark surface the white cutouts (the heart in the "e", the gap in its swoosh) show the
    surface through them, and the glossy highlight beside the heart reads as a slightly darker
    red. That is what removing a white background does; it looks right at app sizes.
- **Colour:** brand red `#DC2626`. **Note:** the supplied logo's red is `#D81D1F` (216, 29, 31), a
  little deeper than the `#DC2626` token, so buttons sit a hair lighter than the logo where the
  two appear together (e.g. the Welcome screen). It hasn't been reconciled: changing the token
  would restyle the whole app, so it's a call for the client or a designer. Wired into the app
  as `AppColors.primary`
  ([`mobile/lib/core/theme/app_colors.dart`](../mobile/lib/core/theme/app_colors.dart))
  and `color.primary` in [`docs/07-ui-ux-design.md`](../docs/07-ui-ux-design.md) §4.1.
- **App icon:** a red "E" monogram on white, applied to the Android/iOS/web launcher
  icons already in `/mobile`. **It has not been updated to the new logo** and no longer matches
  it (the same "E" also shows as the native launch screen before the app draws). Deriving a
  square icon from this wordmark is a design decision (crop the "e"? a heart mark?) left to the
  client or a designer. It's a placeholder-professional mark generated to unblock
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
