import 'dart:ui' as ui;

import 'package:datingapp/core/theme/app_colors.dart';
import 'package:datingapp/core/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The logo files and the colour that goes with them. The splash is the white
/// logo on the logo's own red, so what must not be able to drift silently is:
/// the red asset really is `AppColors.logoRed`, and the white asset really is the
/// same artwork (same shape, same size) in white.
class _Pixels {
  _Pixels(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final ByteData rgba;

  int alpha(int i) => rgba.getUint8(i * 4 + 3);
  (int, int, int) rgb(int i) => (
    rgba.getUint8(i * 4),
    rgba.getUint8(i * 4 + 1),
    rgba.getUint8(i * 4 + 2),
  );
}

Future<_Pixels> _decode(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final image = (await codec.getNextFrame()).image;
  final bytes = (await image.toByteData())!;
  return _Pixels(image.width, image.height, bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the red logo asset is exactly AppColors.logoRed', (
    tester,
  ) async {
    final logo = (await tester.runAsync(
      () => _decode('assets/branding/elcarino-logo.png'),
    ))!;

    final solid = <(int, int, int)>{};
    for (var i = 0; i < logo.width * logo.height; i++) {
      if (logo.alpha(i) == 255) solid.add(logo.rgb(i));
    }

    // Every fully opaque pixel is the one red, and it is the token's red.
    expect(solid, hasLength(1));
    final (r, g, b) = solid.single;
    expect(Color.fromARGB(255, r, g, b), AppColors.logoRed);
  });

  testWidgets('the white logo is the same artwork, only white', (tester) async {
    final red = (await tester.runAsync(
      () => _decode('assets/branding/elcarino-logo.png'),
    ))!;
    final white = (await tester.runAsync(
      () => _decode('assets/branding/elcarino-logo-white.png'),
    ))!;

    expect((white.width, white.height), (red.width, red.height));

    var mismatchedAlpha = 0;
    var tinted = 0;
    var opaqueNotWhite = 0;
    for (var i = 0; i < white.width * white.height; i++) {
      if (white.alpha(i) != red.alpha(i)) mismatchedAlpha++;
      if (white.alpha(i) == 0) continue;
      final (r, g, b) = white.rgb(i);
      // Flutter hands back partly transparent pixels premultiplied, so a soft
      // white edge reads as grey. What must hold is that it is never coloured.
      if (r != g || g != b) tinted++;
      if (white.alpha(i) == 255 && (r, g, b) != (255, 255, 255)) {
        opaqueNotWhite++;
      }
    }
    expect(mismatchedAlpha, 0, reason: 'same shape, pixel for pixel');
    expect(tinted, 0, reason: 'no red left anywhere');
    expect(opaqueNotWhite, 0, reason: 'every solid pixel is exactly white');
  });

  testWidgets('AppLogo picks the white asset only when asked', (tester) async {
    Future<String> assetFor(AppLogo logo) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: logo)));
      final image = tester.widget<Image>(find.byType(Image));
      return (image.image as AssetImage).assetName;
    }

    expect(
      await assetFor(const AppLogo()),
      'assets/branding/elcarino-logo.png',
    );
    expect(
      await assetFor(const AppLogo(white: true)),
      'assets/branding/elcarino-logo-white.png',
    );
  });

  test('the logo red is distinct from the UI accent, on purpose', () {
    // Documented in AppColors.logoRed: the logo's own red is used only for the
    // splash background; buttons and highlights stay the primary token.
    expect(AppColors.logoRed, isNot(AppColors.primary));
  });
}
