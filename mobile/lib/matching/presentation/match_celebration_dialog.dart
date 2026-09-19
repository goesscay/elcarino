import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../chat/domain/conversation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/network_photo.dart';
import '../../discovery/domain/candidate.dart';

/// docs/07-ui-ux-design.md §3.2 "Match celebration": a full-screen moment on
/// a mutual like — both photos, "It's a Match!", Send a message / Keep
/// discovering.
///
/// Always dark, whatever the app theme: it's a moment, not a page, and two
/// portraits read best on black. Restrained on purpose — the two photos slide
/// together, the heart pops between them, the text fades up, then it's still.
/// No confetti, no shower of hearts.
///
/// [myPhotoUrl] is the viewer's own primary photo, resolved by the caller
/// (this stays pure UI with no repository of its own). `null` — the profile
/// fetch failed, or there's no photo — shows a neutral placeholder rather
/// than blocking the celebration on it.
///
/// [conversation] is the `Conversation` the caller already resolved for this
/// match (Chat, item 8). `null` is a defensive fallback (`SwipeService` always
/// creates one alongside every `UserMatch`) that shows a notice instead of a
/// dead navigation.
Future<void> showMatchCelebration(
  BuildContext context,
  DiscoveryCandidate matchedWith, {
  Conversation? conversation,
  String? myPhotoUrl,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.modalBarrier,
    builder: (dialogContext) => Theme(
      data: AppTheme.dark,
      child: Dialog.fullscreen(
        backgroundColor: AppColors.bgDark,
        child: _MatchContent(
          theirPhotoUrl: matchedWith.photos.isEmpty
              ? null
              : matchedWith.photos.first.url,
          myPhotoUrl: myPhotoUrl,
          onSendMessage: () {
            Navigator.of(dialogContext).pop();
            if (conversation != null) {
              context.push('/chat/${conversation.id}', extra: conversation);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Couldn't open the chat — try it from Chats."),
                ),
              );
            }
          },
          onKeepDiscovering: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    ),
  );
}

class _MatchContent extends StatefulWidget {
  const _MatchContent({
    required this.theirPhotoUrl,
    required this.myPhotoUrl,
    required this.onSendMessage,
    required this.onKeepDiscovering,
  });

  final String? theirPhotoUrl;
  final String? myPhotoUrl;
  final VoidCallback onSendMessage;
  final VoidCallback onKeepDiscovering;

  @override
  State<_MatchContent> createState() => _MatchContentState();
}

class _MatchContentState extends State<_MatchContent>
    with SingleTickerProviderStateMixin {
  static const _photoSize = 156.0;
  static const _overlap = 40.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce-motion: land on the final frame instead of animating (docs/07
    // §4.5).
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final slide = _interval(0, 0.55, Curves.easeOutCubic);
    final heart = _interval(0.45, 0.85, Curves.elasticOut);
    final copy = _interval(0.5, 0.9, Curves.easeOut);

    return SafeArea(
      child: Stack(
        children: [
          // A soft red glow behind the photos — the one splash of brand
          // colour, kept low so the photos stay the focus.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.9,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.22),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: Column(
              children: [
                const Spacer(flex: 3),
                SizedBox(
                  height: _photoSize + 8,
                  width: _photoSize * 2 - _overlap + 8,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: -90 * (1 - slide.value),
                          child: Opacity(
                            opacity: slide.value,
                            child: _MatchPhoto(
                              url: widget.myPhotoUrl,
                              size: _photoSize,
                              label: 'Your photo',
                            ),
                          ),
                        ),
                        Positioned(
                          right: -90 * (1 - slide.value),
                          child: Opacity(
                            opacity: slide.value,
                            child: _MatchPhoto(
                              url: widget.theirPhotoUrl,
                              size: _photoSize,
                              label: 'Their photo',
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: heart.value.clamp(0.0, 1.4),
                          child: const _HeartBadge(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                FadeTransition(
                  opacity: copy,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(copy),
                    child: Column(
                      children: [
                        Text(
                          "It's a Match!",
                          style: text.displaySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'You both liked each other.',
                          style: text.bodyLarge?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 4),
                FadeTransition(
                  opacity: copy,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      children: [
                        FilledButton(
                          onPressed: widget.onSendMessage,
                          child: const Text('Send a message'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: widget.onKeepDiscovering,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.onPhoto,
                            side: const BorderSide(
                              color: AppColors.onPhotoFaint,
                            ),
                          ),
                          child: const Text('Keep discovering'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One circular portrait with a ring in the screen's own colour, so where the
/// two overlap reads as a clean cut rather than a smudge.
class _MatchPhoto extends StatelessWidget {
  const _MatchPhoto({
    required this.url,
    required this.size,
    required this.label,
  });

  final String? url;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: label,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgDark,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            width: size,
            height: size,
            child: ClipOval(
              child: url == null
                  ? const PhotoPlaceholder(iconSize: 48)
                  : NetworkPhoto(url!),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartBadge extends StatelessWidget {
  const _HeartBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bgDark,
      ),
      child: Padding(
        padding: EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
          ),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.favorite_rounded,
              color: AppColors.onPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
