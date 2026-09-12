import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/gender.dart';
import '../../profile/domain/preferences.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Preferences": interested-in multi-select,
/// age range, max distance, and collapsible advanced filters (religion,
/// politics — free-form here; docs/03 notes no fixed value list exists yet).
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  RangeValues _ageRange = const RangeValues(21, 40);
  double _maxDistanceKm = 50;
  final Set<Gender> _interestedIn = {};
  final List<String> _religionFilter = [];
  final List<String> _politicsFilter = [];
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_interestedIn.isEmpty) {
      setState(() => _error = 'Choose at least one "interested in" option.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(profileRepositoryProvider)
          .updatePreferences(
            Preferences(
              minAge: _ageRange.start.round(),
              maxAge: _ageRange.end.round(),
              maxDistanceKm: _maxDistanceKm.round(),
              interestedInGenders: _interestedIn.toList(),
              religionFilter: _religionFilter,
              politicsFilter: _politicsFilter,
            ),
          );
      if (!mounted) return;
      context.go('/onboarding/location');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Preferences',
      step: 4,
      child: ListView(
        children: [
          Text('Interested in', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final gender in Gender.values)
                FilterChip(
                  label: Text(gender.label),
                  selected: _interestedIn.contains(gender),
                  onSelected: (selected) => setState(
                    () => selected ? _interestedIn.add(gender) : _interestedIn.remove(gender),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Age range: ${_ageRange.start.round()}–${_ageRange.end.round()}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          RangeSlider(
            values: _ageRange,
            min: 18,
            max: 100,
            divisions: 82,
            onChanged: (values) => setState(() => _ageRange = values),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Max distance: ${_maxDistanceKm.round()} km', style: Theme.of(context).textTheme.bodyMedium),
          Slider(
            value: _maxDistanceKm,
            min: 1,
            max: 200,
            divisions: 199,
            onChanged: (value) => setState(() => _maxDistanceKm = value),
          ),
          const SizedBox(height: AppSpacing.xl),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Advanced filters (optional)'),
            children: [
              _ChipInput(
                label: 'Religion',
                values: _religionFilter,
                onChanged: (values) => setState(() {
                  _religionFilter
                    ..clear()
                    ..addAll(values);
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChipInput(
                label: 'Politics',
                values: _politicsFilter,
                onChanged: (values) => setState(() {
                  _politicsFilter
                    ..clear()
                    ..addAll(values);
                }),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

/// A free-text tag list — used for religion/politics since no fixed option
/// list exists anywhere in /docs (see docs/03-api-specification.md's note on
/// this).
class _ChipInput extends StatefulWidget {
  const _ChipInput({required this.label, required this.values, required this.onChanged});

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ChipInput> createState() => _ChipInputState();
}

class _ChipInputState extends State<_ChipInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty || widget.values.contains(value)) return;
    widget.onChanged([...widget.values, value]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(labelText: widget.label),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(icon: const Icon(Icons.add), onPressed: _add),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final value in widget.values)
              Chip(
                label: Text(value),
                onDeleted: () => widget.onChanged(widget.values.where((v) => v != value).toList()),
              ),
          ],
        ),
      ],
    );
  }
}
