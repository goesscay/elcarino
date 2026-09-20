import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/network_photo.dart';
import '../../core/widgets/state_message.dart';
import '../data/profile_repository.dart';
import '../domain/interest.dart';
import '../domain/profile.dart';
import '../domain/prompt.dart';

/// docs/07-ui-ux-design.md §3.5 "My profile": preview as others see it,
/// completion meter, Edit profile entry point, verification status, gear ->
/// Settings. "Edit preferences" is a peer of "Edit profile" in that doc's
/// table (not one of Edit profile's sections), so it gets its own button here
/// rather than living in the Edit-profile menu.
///
/// The profile itself is required; the viewer's interests and prompt answers
/// (existing read endpoints, the same ones the edit screens use) are
/// best-effort extras — if either fails to load the screen still shows,
/// just without that section.
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  Profile? _profile;
  List<Interest> _interests = const [];
  List<AnsweredPrompt> _prompts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<T>> _bestEffort<T>(Future<List<T>> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> _load() async {
    setState(() {
      // Only blank the screen for the very first load; a refresh (pull-down,
      // back from editing) updates in place.
      _loading = _profile == null;
      _error = null;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      final (profile, interests, prompts) = await (
        repo.getProfile(),
        _bestEffort(repo.getMyInterests),
        _bestEffort(repo.getMyPrompts),
      ).wait;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _interests = interests;
        _prompts = prompts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your profile.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        toolbarHeight: 64,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _ProfileSkeleton();
    if (_error != null) {
      return StateMessage(
        icon: Icons.error_outline,
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    final profile = _profile;
    if (profile == null) {
      return const StateMessage(
        icon: Icons.person_outline,
        title: 'No profile yet',
        message: 'Finish setting up your profile to start meeting people.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ProfileView(
        profile: profile,
        interests: _interests,
        prompts: _prompts,
        onEditProfile: () => context.push('/profile/edit').then((_) => _load()),
        onEditPreferences: () => context.push('/profile/preferences'),
        onVerify: () => context.push('/verification').then((_) => _load()),
      ),
    );
  }
}

/// The profile as a scrollable page. Stateless and data-in/callbacks-out so
/// it can be rendered and tested without a repository.
class ProfileView extends StatelessWidget {
  const ProfileView({
    required this.profile,
    required this.interests,
    required this.prompts,
    required this.onEditProfile,
    required this.onEditPreferences,
    this.onVerify,
    super.key,
  });

  final Profile profile;
  final List<Interest> interests;
  final List<AnsweredPrompt> prompts;
  final VoidCallback onEditProfile;
  final VoidCallback onEditPreferences;

  /// Opens the verification flow. The "Get verified" card only shows when this
  /// is set and the profile isn't verified yet.
  final VoidCallback? onVerify;

  static const _avatarSize = 128.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bio = profile.bio;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      children: [
        Center(
          child: _Avatar(
            url: profile.photos.isEmpty ? null : profile.photos.first.url,
            size: _avatarSize,
            verified: profile.isVerified,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '${profile.displayName}, ${ageFromBirthDate(profile.birthDate)}',
          textAlign: TextAlign.center,
          style: text.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(child: _VerificationPill(verified: profile.isVerified)),
        const SizedBox(height: AppSpacing.xl),
        if (!profile.isVerified && onVerify != null) ...[
          _VerifyCard(onPressed: onVerify!),
          const SizedBox(height: AppSpacing.lg),
        ],
        _CompletenessCard(percent: profile.completionPct),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: onEditProfile,
          child: const Text('Edit profile'),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: onEditPreferences,
          child: const Text('Edit preferences'),
        ),
        if (bio != null && bio.isNotEmpty)
          _Section(
            title: 'About me',
            child: Text(bio, style: text.bodyLarge),
          ),
        if (interests.isNotEmpty)
          _Section(
            title: 'Interests',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final i in interests)
                  // Display-only, so no 48pt tap-target padding around it.
                  Chip(
                    label: Text(i.name),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
        if (prompts.isNotEmpty)
          _Section(
            title: 'Prompts',
            child: Column(
              children: [
                for (final prompt in prompts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _PromptCard(prompt: prompt),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Age in whole years on [now] (default: today).
int ageFromBirthDate(DateTime birthDate, {DateTime? now}) {
  final current = now ?? DateTime.now();
  var age = current.year - birthDate.year;
  if (current.month < birthDate.month ||
      (current.month == birthDate.month && current.day < birthDate.day)) {
    age -= 1;
  }
  return age;
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.size,
    required this.verified,
  });

  final String? url;
  final double size;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: url == null
                  ? const PhotoPlaceholder(iconSize: 56)
                  : NetworkPhoto(url!),
            ),
          ),
          if (verified)
            Positioned(
              right: 2,
              bottom: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.background,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.verified,
                    color: AppColors.success,
                    size: 28,
                    semanticLabel: 'Verified',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VerificationPill extends StatelessWidget {
  const _VerificationPill({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = verified ? AppColors.success : p.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Icons.verified : Icons.verified_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              verified ? 'Verified' : 'Not verified',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The nudge to get verified: one soft card, brand-tinted, on the profile of
/// anyone who isn't yet. Gone once they are (the pill above says "Verified").
class _VerifyCard extends StatelessWidget {
  const _VerifyCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Get verified. Show you are really you with a quick selfie.',
      excludeSemantics: true,
      child: Material(
        color: p.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Get verified', style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Show you are really you with a quick selfie.',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Profile completeness', style: text.titleMedium),
                ),
                Text(
                  '$percent%',
                  style: text.titleMedium?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 8,
                color: AppColors.primary,
                backgroundColor: p.fill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt});

  final AnsweredPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prompt.promptText.isNotEmpty)
                Text(
                  prompt.promptText,
                  style: text.labelMedium?.copyWith(color: p.textSecondary),
                ),
              const SizedBox(height: AppSpacing.xs),
              Text(prompt.answer, style: text.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// A calm placeholder for the first load: the avatar, a name line and a card,
/// in the neutral fill, so the layout doesn't jump when content arrives.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final fill = context.palette.fill;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Center(
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(child: bar(160, 24)),
        const SizedBox(height: AppSpacing.md),
        Center(child: bar(100, 20)),
        const SizedBox(height: AppSpacing.xl),
        Container(
          height: 84,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ],
    );
  }
}
