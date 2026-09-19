import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Shared chrome for the wizard steps — docs/07-ui-ux-design.md §3.1's
/// "Profile basics" row calls out "Progress `1 / 5`"; applied here to the 5
/// numbered data/permission steps (basics/photos/prompts/preferences/
/// location). Notification-permission and "onboarding complete" are shown
/// without a progress bar, same as the doc's own row for them omits one.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.title,
    required this.child,
    this.step,
    this.actions,
    super.key,
  });

  static const totalSteps = 5;

  final String title;
  final int? step;
  final Widget child;

  /// Optional AppBar actions (e.g. Preferences' "Reset").
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        bottom: step == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: step! / totalSteps),
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          child: child,
        ),
      ),
    );
  }
}
