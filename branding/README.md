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
  would restyle the whole app, so it's a call for the client or a designer. The logo's own red
  is used in exactly one place, the splash background, as `AppColors.logoRed`; everything
  else stays on the primary token. Wired into the app
  as `AppColors.primary`
  ([`mobile/lib/core/theme/app_colors.dart`](../mobile/lib/core/theme/app_colors.dart))
  and `color.primary` in [`docs/07-ui-ux-design.md`](../docs/07-ui-ux-design.md) §4.1.
- **App icon:** the client-supplied "e" icon: a red mark with a white heart cut out of it.
  [`app-icon-source.png`](app-icon-source.png) is **the icon exactly as supplied** (a 1254 px
  render of a white puffy tile with a soft shadow and glow holding the mark), converted to PNG
  losslessly and otherwise untouched. Phones draw their own rounded tile and shadow, so the
  supplied tile itself is not shipped (that would be a tile inside a tile, with white corners
  on iOS). [`prepare_icons.py`](prepare_icons.py) lifts the **mark** out of the artwork exactly
  as drawn (its gradients and shading are kept; nothing is redrawn or recoloured) and places it
  on white, so the system supplies the tile. See "Regenerating the app icon" below.
- **Splash / launch screen:** the logo in **white**, centred, on a **full-bleed background of
  the logo's own red** (`#D81D1F`, `AppColors.logoRed`), in light and dark mode alike. The native
  launch screen (Android, iOS) and the in-app `SplashScreen` are identical (same colour, same
  170 dp logo), so the hand-off between them is invisible. The white logo is the same artwork
  and the same shape as the red one with only the colour swapped
  ([`elcarino-logo-white.png`](elcarino-logo-white.png), made by `prepare_logo.py`), never a
  tint applied at runtime. A test checks that the red asset really is `AppColors.logoRed` and
  that the white asset is pixel-for-pixel the same shape. See "Regenerating the splash screen".
- **Package/bundle id:** `com.mgs.elcarino` (Android `applicationId`/`namespace`, iOS
  `PRODUCT_BUNDLE_IDENTIFIER`).

Not touched: the Dart package name (`name: datingapp` in `mobile/pubspec.yaml`) and the
`package:datingapp/...` import prefix. That's a purely internal Dart identifier with no
user-facing exposure — renaming it means updating every import for zero visible benefit,
so it was deliberately left alone. Flag it if that changes.

## Regenerating the app icon

```
python branding/prepare_icons.py        # needs Pillow; writes into mobile/ (Android, iOS, web)
```

It writes, from `app-icon-source.png`:

- **Android (8+): an adaptive icon.** A white background layer
  (`values/ic_launcher_background.xml`) and the mark as the foreground
  (`mipmap-*/ic_launcher_foreground.png`, 108 dp, the mark kept inside the 66 dp safe zone so
  it survives circle, squircle and teardrop masks), wired by `mipmap-anydpi-v26/ic_launcher.xml`.
- **Android (before 8): legacy icons**, a rounded white tile with transparent corners
  (`mipmap-*/ic_launcher.png`, 48-192 px).
- **iOS:** every size `AppIcon.appiconset/Contents.json` lists, including the 1024 px marketing
  icon, as an **opaque square** (iOS rounds it, and App Store Connect rejects an icon with an
  alpha channel).
- **Web:** 192/512 px, maskable variants (mark inside the safe zone), and the favicon.

**Not done:** an Android 13+ *themed* (monochrome) icon layer. It would use the mark's
silhouette; without it the icon simply isn't tinted when a user turns on themed icons.

## Regenerating the splash screen

```
python branding/prepare_logo.py         # writes the white logo and the launch-screen inputs
cd mobile && dart run flutter_native_splash:create
```

`prepare_logo.py` writes `mobile/tool/splash/splash_logo.png` and `splash_android12.png` (the
package treats an image as 4x density, so both are drawn at 170 dp), and the config lives in
the `flutter_native_splash:` block of `mobile/pubspec.yaml`. Android 12+ draws its splash icon
inside a circle, so `splash_android12.png` puts the wide wordmark on a 288 dp canvas small
enough that its corners stay inside that circle. Android 12+ shows the logo in that fixed-size
window for a moment before the app draws; older Android and iOS show it centred full-screen.
The web build (a dev preview only) has no generated splash.

**Verified on** an Android 14 emulator only. The iOS launch screen (`LaunchScreen.storyboard`
and the `LaunchImage`/`LaunchBackground` image sets) and the iOS icon set are generated to
the standard structure but **have not been built or run on iOS** (no iOS toolchain on the dev
machine); check both in Xcode/a simulator before submitting to the App Store.
