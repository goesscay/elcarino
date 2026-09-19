import 'package:flutter/material.dart';

/// The Elcarino wordmark, exactly as provided in `/branding` — the PNG is
/// copied byte-for-byte and is never recoloured, tinted, stretched or redrawn
/// here. Size it by [width] only; height follows the asset's own aspect ratio.
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
