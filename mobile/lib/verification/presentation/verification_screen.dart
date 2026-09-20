import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/state_message.dart';
import '../data/selfie_capture.dart';
import '../data/verification_repository.dart';
import '../domain/verification.dart';

enum _Phase { loading, intro, submitting, result, blocked, error }

/// docs/07 §3.6 "Verification": intro -> selfie -> processing -> result, as one
/// screen that moves through those steps.
///
/// The person is shown the pose the server picked, takes a front-camera selfie
/// (camera only — a gallery photo would defeat the point), and the server
/// answers on the spot: a confident match is approved, a clear "no face" is
/// rejected so they can retake it, and everything else goes to a human reviewer
/// (open decision #22). It never says *why* something went to review, and never
/// shows a score.
///
/// The screen reads the current state first, so opening it when already
/// verified, already in review, or out of attempts shows that instead of
/// inviting a doomed selfie.
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  _Phase _phase = _Phase.loading;
  VerificationChallenge? _challenge;
  VerificationRequestInfo? _result;
  String? _lastRejection;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final repository = ref.read(verificationRepositoryProvider);
      final state = await repository.getStatus();
      if (!mounted) return;

      final request = state.request;
      if (state.isVerified) {
        return _show(_Phase.result, result: _approvedFallback(request));
      }
      if (request != null && request.outcome == VerificationOutcome.inReview) {
        return _show(_Phase.result, result: request);
      }
      if (!state.canStart) {
        return _show(
          _Phase.blocked,
          message: "You've reached today's verification limit. Please try again tomorrow.",
        );
      }

      final challenge = await repository.getChallenge();
      if (!mounted) return;
      _lastRejection = request?.outcome == VerificationOutcome.rejected
          ? request?.reasonMessage
          : null;
      setState(() {
        _challenge = challenge;
        _phase = _Phase.intro;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _show(_Phase.error, message: e.message);
    }
  }

  /// Verified with no request row to show (e.g. verified before this feature).
  VerificationRequestInfo _approvedFallback(VerificationRequestInfo? request) =>
      request ??
      VerificationRequestInfo(
        id: 0,
        outcome: VerificationOutcome.approved,
        submittedAt: DateTime.now(),
      );

  void _show(_Phase phase, {VerificationRequestInfo? result, String? message}) {
    setState(() {
      _phase = phase;
      _result = result;
      _message = message;
    });
  }

  Future<void> _takeSelfie() async {
    final challenge = _challenge;
    if (challenge == null) return;

    final path = await ref.read(selfieCaptureProvider).capture();
    if (path == null || !mounted) return;

    setState(() => _phase = _Phase.submitting);
    try {
      final result = await ref
          .read(verificationRepositoryProvider)
          .submit(selfiePath: path, pose: challenge.pose);
      if (!mounted) return;
      _show(_Phase.result, result: result);
    } on ApiException catch (e) {
      if (!mounted) return;
      await _recover(e);
    }
  }

  /// A refused submission is usually recoverable: the prompt expired (get a new
  /// one), or state moved on since the screen opened (read it again).
  Future<void> _recover(ApiException e) async {
    switch (e.code) {
      case 'challenge_expired':
        try {
          final fresh = await ref
              .read(verificationRepositoryProvider)
              .getChallenge();
          if (!mounted) return;
          setState(() {
            _challenge = fresh;
            _phase = _Phase.intro;
          });
          _snack('That prompt expired. Here is a new one.');
        } on ApiException catch (inner) {
          if (mounted) _show(_Phase.error, message: inner.message);
        }
      case 'verification_in_progress' || 'already_verified':
        await _load();
      case 'too_many_attempts':
        _show(_Phase.blocked, message: e.message);
      default:
        // photo_required, invalid_image, validation... say what happened and
        // let them try again with the same prompt.
        setState(() => _phase = _Phase.intro);
        _snack(e.message);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _done() => context.pop(_result?.outcome == VerificationOutcome.approved);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get verified')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() => switch (_phase) {
    _Phase.loading => const Center(child: CircularProgressIndicator()),
    _Phase.intro => _Intro(
      challenge: _challenge!,
      lastRejection: _lastRejection,
      onTakeSelfie: _takeSelfie,
    ),
    _Phase.submitting => const _Submitting(),
    _Phase.result => _ResultView(
      result: _result!,
      onDone: _done,
      onRetry: _load,
    ),
    _Phase.blocked => StateMessage(
      icon: Icons.schedule_rounded,
      title: 'Come back tomorrow',
      message: _message ?? '',
      actionLabel: 'Done',
      onAction: _done,
    ),
    _Phase.error => StateMessage(
      icon: Icons.error_outline,
      message: _message ?? 'Something went wrong.',
      actionLabel: 'Retry',
      onAction: _load,
    ),
  };
}

class _Intro extends StatelessWidget {
  const _Intro({
    required this.challenge,
    required this.lastRejection,
    required this.onTakeSelfie,
  });

  final VerificationChallenge challenge;
  final String? lastRejection;
  final VoidCallback onTakeSelfie;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: [
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Icon(
                      Icons.verified_user_outlined,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                "Show you're really you",
                textAlign: TextAlign.center,
                style: text.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'A quick selfie earns the verified badge, so people know the '
                'photos on your profile are really you.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: p.textSecondary),
              ),
              if (lastRejection != null) ...[
                const SizedBox(height: AppSpacing.xl),
                _Notice(message: lastRejection!),
              ],
              const SizedBox(height: AppSpacing.xl),
              _PoseCard(label: challenge.label),
              const SizedBox(height: AppSpacing.xl),
              const _Point(
                icon: Icons.photo_camera_front_outlined,
                text: 'Take a selfie showing the pose above.',
              ),
              const _Point(
                icon: Icons.compare_outlined,
                text: 'We compare it with your profile photos.',
              ),
              const _Point(
                icon: Icons.lock_outline_rounded,
                text:
                    'Your selfie is encrypted, used only for this check, and '
                    'deleted as soon as it is done. It is never shown to '
                    'other people.',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          child: FilledButton.icon(
            onPressed: onTakeSelfie,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take selfie'),
          ),
        ),
      ],
    );
  }
}

/// The pose to strike, big and unmissable.
class _PoseCard extends StatelessWidget {
  const _PoseCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Your pose: $label',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Text('Your pose', style: text.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(label, textAlign: TextAlign.center, style: text.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: p.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// What went wrong last time, on the intro screen when they come back to retry.
class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: AppColors.danger,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Submitting extends StatelessWidget {
  const _Submitting();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.xl),
            Text('Checking your selfie…', style: text.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This usually takes just a moment.',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.onDone,
    required this.onRetry,
  });

  final VerificationRequestInfo result;
  final VoidCallback onDone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (result.outcome) {
      VerificationOutcome.approved => StateMessage(
        icon: Icons.verified_rounded,
        celebratory: true,
        title: "You're verified",
        message: 'Your profile now shows the verified badge.',
        actionLabel: 'Done',
        onAction: onDone,
      ),
      VerificationOutcome.inReview => StateMessage(
        icon: Icons.hourglass_top_rounded,
        title: "We're reviewing your selfie",
        message:
            "A person is taking a look. We'll notify you as soon as there's "
            'an answer — you can leave this screen.',
        actionLabel: 'Done',
        onAction: onDone,
      ),
      VerificationOutcome.rejected => _Rejected(
        message:
            result.reasonMessage ??
            "We couldn't verify you this time. You can try again.",
        onRetry: onRetry,
        onDone: onDone,
      ),
    };
  }
}

class _Rejected extends StatelessWidget {
  const _Rejected({
    required this.message,
    required this.onRetry,
    required this.onDone,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StateMessage(
            icon: Icons.error_outline_rounded,
            title: "Couldn't verify you",
            message: message,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onDone, child: const Text('Not now')),
            ],
          ),
        ),
      ],
    );
  }
}
