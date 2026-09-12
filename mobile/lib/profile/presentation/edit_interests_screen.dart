import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../data/profile_repository.dart';
import '../domain/interest.dart';

/// docs/07-ui-ux-design.md §3.5 "Edit profile" -> interests section. No max
/// count is enforced client-side (unlike photos' 6-slot grid, which mirrors a
/// fixed UI layout) — `media.max_interests_per_profile` on the backend is a
/// provisional number, not worth duplicating client-side; a 422 surfaces the
/// same way any other validation failure does.
class EditInterestsScreen extends ConsumerStatefulWidget {
  const EditInterestsScreen({super.key});

  @override
  ConsumerState<EditInterestsScreen> createState() => _EditInterestsScreenState();
}

class _EditInterestsScreenState extends ConsumerState<EditInterestsScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<Interest> _catalogue = [];
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repository = ref.read(profileRepositoryProvider);
      final catalogue = await repository.getInterestCatalogue();
      final mine = await repository.getMyInterests();
      if (!mounted) return;
      setState(() {
        _catalogue = catalogue;
        _selectedIds.addAll(mine.map((i) => i.id));
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateInterests(_selectedIds.toList());
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ValidationException catch (e) {
      setState(() => _error = e.firstError('interest_ids') ?? 'Check your selection.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<Interest>>{};
    for (final interest in _catalogue) {
      byCategory.putIfAbsent(interest.category ?? 'Other', () => []).add(interest);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Interests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          for (final category in byCategory.keys) ...[
                            Text(category, style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                for (final interest in byCategory[category]!)
                                  FilterChip(
                                    label: Text(interest.name),
                                    selected: _selectedIds.contains(interest.id),
                                    onSelected: (selected) => setState(
                                      () => selected
                                          ? _selectedIds.add(interest.id)
                                          : _selectedIds.remove(interest.id),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
