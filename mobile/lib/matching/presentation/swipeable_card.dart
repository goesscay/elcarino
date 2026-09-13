import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../discovery/domain/candidate.dart';
import '../domain/swipe_direction.dart';

/// docs/07-ui-ux-design.md §3.2 "Card stack": drag gesture (left = pass,
/// right = like) with a fly-away animation past a threshold, or a spring-back
/// if released short of it. Swipe-up-for-Super-Like isn't implemented — see
/// swipe_direction.dart's doc comment on why. The card only *renders* and
/// *animates itself* here; the actual API call happens in the parent
/// (DiscoverFeedScreen) once [onSwiped] fires, so this widget has no
/// networking of its own.
class SwipeableCard extends StatefulWidget {
  const SwipeableCard({
    required this.candidate,
    required this.onSwiped,
    super.key,
  });

  final DiscoveryCandidate candidate;
  final ValueChanged<SwipeDirection> onSwiped;

  @override
  State<SwipeableCard> createState() => SwipeableCardState();
}

class SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  static const _swipeThreshold = 110.0;

  late final AnimationController _controller;
  Animation<Offset>? _animation;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          final animation = _animation;
          if (animation != null) setState(() => _dragOffset = animation.value);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) =>
      setState(() => _dragOffset += details.delta);

  void _onPanEnd(DragEndDetails details) {
    if (_dragOffset.dx.abs() > _swipeThreshold) {
      _flyAway(_dragOffset.dx > 0 ? SwipeDirection.right : SwipeDirection.left);
    } else {
      _animateTo(Offset.zero, Curves.easeOut);
    }
  }

  void _flyAway(SwipeDirection direction) {
    final screenWidth = MediaQuery.of(context).size.width;
    final endX = direction == SwipeDirection.right
        ? screenWidth * 1.5
        : -screenWidth * 1.5;
    _animateTo(
      Offset(endX, _dragOffset.dy),
      Curves.easeIn,
    ).whenComplete(() => widget.onSwiped(direction));
  }

  TickerFuture _animateTo(Offset end, Curve curve) {
    _animation = Tween<Offset>(
      begin: _dragOffset,
      end: end,
    ).animate(CurvedAnimation(parent: _controller, curve: curve));
    return _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final angle = (_dragOffset.dx / 300).clamp(-0.4, 0.4);

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: angle,
          child: Stack(
            children: [
              _CardFace(candidate: widget.candidate),
              if (_dragOffset.dx > 20)
                const Positioned(
                  top: 24,
                  left: 24,
                  child: _Stamp(label: 'LIKE', color: Colors.green),
                ),
              if (_dragOffset.dx < -20)
                const Positioned(
                  top: 24,
                  right: 24,
                  child: _Stamp(label: 'PASS', color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.candidate});

  final DiscoveryCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            candidate.photos.isEmpty
                ? Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Icon(Icons.person, size: 96),
                  )
                : Image.network(candidate.photos.first.url, fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${candidate.displayName}, ${candidate.age}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (candidate.isVerified) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      candidate.distanceLabel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (candidate.bio != null && candidate.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          candidate.bio!,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
