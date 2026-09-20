import 'package:flutter/material.dart';

/// The Elcarino logo, exactly as provided in `/branding` — the PNG is a
/// byte-for-byte copy of `branding/elcarino-logo.png` (the supplied artwork with
/// its margin trimmed and its background made transparent, see
/// `branding/README.md`) and is never recoloured, tinted, stretched or redrawn
/// here. It is transparent so the same asset works on the light and the dark
/// surfaces. Size it by [width] only; height follows the asset's own aspect ratio.
class AppLogo extends StatelessWidget {
  const AppLogo({this.width = 180, this.white = false, super.key});

  final double width;

  /// The logo in white, for the splash screen (white on the logo-red
  /// background). It is the same artwork with the same shape and only the colour
  /// swapped (see `branding/prepare_logo.py`), never a tint applied at runtime.
  final bool white;

  static const _asset = 'assets/branding/elcarino-logo.png';
  static const _whiteAsset = 'assets/branding/elcarino-logo-white.png';

  @override
  Widget build(BuildContext context) => Image.asset(
    white ? _whiteAsset : _asset,
    width: width,
    fit: BoxFit.contain,
    semanticLabel: 'Elcarino',
  );
}
