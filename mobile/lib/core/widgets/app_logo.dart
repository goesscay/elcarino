import 'package:flutter/material.dart';

/// The Elcarino logo, exactly as provided in `/branding` — the PNG is a
/// byte-for-byte copy of `branding/elcarino-logo.png` (the supplied artwork with
/// its margin trimmed and its background made transparent, see
/// `branding/README.md`) and is never recoloured, tinted, stretched or redrawn
/// here. It is transparent so the same asset works on the light and the dark
/// surfaces. Size it by [width] only; height follows the asset's own aspect ratio.
class AppLogo extends StatelessWidget {
  const AppLogo({this.width = 180, super.key});

  final double width;

  static const _asset = 'assets/branding/elcarino-logo.png';

  @override
  Widget build(BuildContext context) => Image.asset(
    _asset,
    width: width,
    fit: BoxFit.contain,
    semanticLabel: 'Elcarino',
  );
}
