import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/network_photo.dart';
import '../../discovery/domain/candidate.dart';
import '../domain/swipe_direction.dart';

/// docs/07-ui-ux-design.md §3.2 "Card stack": drag gesture (left = pass,
/// right = like) with a fly-away animation past a threshold, or a spring-back
/// if released short of it. Swipe-up-for-Super-Like isn't implemented — see
/// swipe_direction.dart's doc comment on why. The card only *renders* and
/// *animates itself* here; the actual API call happens in the parent
/// (DiscoverFeedScreen) once [onSwiped] fires, so this widget has no
/// networking of its own.
///
/// [dragProgress] (0 → 1 as the card nears the commit threshold) lets the
/// parent animate the card *behind* this one growing into place as it's
/// dragged away, which is most of what makes a stack feel alive.
class SwipeableCard extends StatefulWidget {
  const SwipeableCard({
    required this.candidate,
    required this.onSwiped,
    this.dragProgress,
    super.key,
  });

  final DiscoveryCandidate candidate;
  final ValueChanged<SwipeDirection> onSwiped;
  final ValueNotifier<double>? dragProgress;

  @override
  State<SwipeableCard> createState() => SwipeableCardState();
}

class SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  static const _swipeThreshold = 110.0;

  late final AnimationController _controller;
  Animation<Offset>? _animation;
  Offset _dragOffset = Offset.zero;
  bool _committedHaptic = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          final animation = _animation;
          if (animation != null) {
            setState(() => _dragOffset = animation.value);
            _reportProgress();
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reportProgress() {
    widget.dragProgress?.value = (_dragOffset.dx.abs() / _swipeThreshold).clamp(
      0.0,
      1.0,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta);
    _reportProgress();
    // A light tick the moment the drag crosses the commit line, so the user
    // feels where "let go now and it counts" starts (docs/07 §4.5).
    final past = _dragOffset.dx.abs() > _swipeThreshold;
    if (past && !_committedHaptic) HapticFeedback.selectionClick();
    _committedHaptic = past;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragOffset.dx.abs() > _swipeThreshold) {
      _flyAway(_dragOffset.dx > 0 ? SwipeDirection.right : SwipeDirection.left);
    } else {
      _animateTo(Offset.zero, Curves.easeOutBack);
    }
  }

  void _flyAway(SwipeDirection direction) {
    HapticFeedback.lightImpact();
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
    // 0 at the start of the drag, 1 at the commit threshold — drives how
    // strongly the LIKE/PASS stamp shows through.
    final stamp = ((_dragOffset.dx.abs() - 16) / (_swipeThreshold - 16)).clamp(
      0.0,
      1.0,
    );

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
              if (_dragOffset.dx > 0)
                Positioned(
                  top: 28,
                  left: 24,
                  child: _Stamp(
                    label: 'LIKE',
                    fill: AppColors.primary,
                    color: AppColors.onPrimary,
                    opacity: stamp,
                    turns: -0.035,
                  ),
                ),
              if (_dragOffset.dx < 0)
                Positioned(
                  top: 28,
                  right: 24,
                  child: _Stamp(
                    label: 'PASS',
                    fill: AppColors.photoControl,
                    color: AppColors.onPhoto,
                    opacity: stamp,
                    turns: 0.035,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card behind the top one — the next candidate's photo only, rounded and
/// lifted the same way so the stack reads as one object. Non-interactive.
class SwipePeekCard extends StatelessWidget {
  const SwipePeekCard({required this.candidate, super.key});

  final DiscoveryCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return _CardShell(child: _CardPhoto(candidate: candidate));
  }
}

/// Rounded clip + the soft lift. The large photo card is the one element in
/// the app that gets a shadow; everything else uses a hairline border.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadius.profileCard));
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _CardPhoto extends StatelessWidget {
  const _CardPhoto({required this.candidate});

  final DiscoveryCandidate candidate;

  @override
  Widget build(BuildContext context) {
    if (candidate.photos.isEmpty) {
      // A photo card always carries a dark scrim, so its empty state is dark
      // in both themes rather than the themed light fill.
      return const PhotoPlaceholder(fill: AppColors.surfaceDark);
    }
    return NetworkPhoto(candidate.photos.first.url);
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.candidate});

  final DiscoveryCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final interests = candidate.sharedInterests.take(3).toList();
    final bio = candidate.bio;

    return _CardShell(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CardPhoto(candidate: candidate),
          // Information sits on a short, soft fade at the bottom — enough for
          // legibility, not a heavy band that eats the photo.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), AppColors.photoScrim],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  56,
                  AppSpacing.screen,
                  AppSpacing.screen,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${candidate.displayName}, ${candidate.age}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge?.copyWith(
                              color: AppColors.onPhoto,
                              fontSize: 26,
                            ),
                          ),
                        ),
                        if (candidate.isVerified) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(
                            Icons.verified,
                            color: AppColors.onPhoto,
                            size: 20,
                            semanticLabel: 'Verified',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.onPhotoMuted,
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          candidate.distanceLabel,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.onPhotoMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.onPhoto,
                        ),
                      ),
                    ],
                    if (interests.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final interest in interests)
                            _PhotoChip(label: interest),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small translucent pill for text that sits on a photo.
class _PhotoChip extends StatelessWidget {
  const _PhotoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.onPhotoFaint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: AppColors.onPhoto),
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.fill,
    required this.color,
    required this.opacity,
    required this.turns,
  });

  final String label;
  final Color fill;
  final Color color;
  final double opacity;
  final double turns;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: turns * 6.2831853,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: color, width: 2.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
