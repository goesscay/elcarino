import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A user's photo, loaded from the network. The app is photo-first, so this is
/// the one place that decides how a photo *arrives*: a quiet neutral fill
/// while it loads, a gentle fade-in when it's ready (rather than popping in),
/// and a calm fallback if it can't be loaded — never a broken-image glyph.
///
/// Crops with [BoxFit.cover], biased toward the top of the frame because a
/// portrait's face sits in the upper part; centre-cropping tends to cut
/// foreheads off in tall cards.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto(
    this.url, {
    this.fit = BoxFit.cover,
    this.alignment = const Alignment(0, -0.35),
    super.key,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final fill = context.palette.fill;
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: fill),
            AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: child,
            ),
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          PhotoPlaceholder(fill: fill),
    );
  }
}

/// The "no photo" / "couldn't load" state for a photo slot.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({this.fill, this.iconSize = 56, super.key});

  final Color? fill;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ColoredBox(
      color: fill ?? p.fill,
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: iconSize,
          color: p.textSecondary,
        ),
      ),
    );
  }
}
