import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// docs/07-ui-ux-design.md §3.5 "My profile": preview as others see it,
/// completion meter, Edit profile entry point, verification status chip,
/// gear -> Settings. "Edit preferences" is a peer of "Edit profile" in that
/// doc's table (not one of Edit profile's sections), so it gets its own
/// button here rather than living in the Edit-profile menu.
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  Profile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(profileRepositoryProvider).getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  int _ageFrom(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age -= 1;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            // Settings' children (account, notifications, privacy, etc.) are
            // scattered across features that aren't built yet (Push
            // notifications item 9, Safety item 10) — no single "Settings"
            // phase item exists to hang a real screen off of yet.
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Settings — coming soon.'))),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _profile == null
            ? const Center(child: Text('No profile yet.'))
            : RefreshIndicator(onRefresh: _load, child: _buildProfile(_profile!)),
      ),
    );
  }

  Widget _buildProfile(Profile profile) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: profile.photos.isEmpty
                ? Container(
                    width: 160,
                    height: 160,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.person, size: 64),
                  )
                : Image.network(
                    profile.photos.first.url,
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            '${profile.displayName}, ${_ageFrom(profile.birthDate)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Chip(
            avatar: const Icon(Icons.verified_outlined, size: 18),
            label: Text(profile.isVerified ? 'Verified' : 'Not verified'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Profile completion: ${profile.completionPct}%'),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(value: profile.completionPct / 100),
        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Bio', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(profile.bio!),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () => context.push('/profile/edit').then((_) => _load()),
          child: const Text('Edit profile'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => context.push('/profile/preferences'),
          child: const Text('Edit preferences'),
        ),
      ],
    );
  }
}
