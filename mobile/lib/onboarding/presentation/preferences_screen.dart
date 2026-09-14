import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/gender.dart';
import '../../profile/domain/preferences.dart';
import '../../subscriptions/data/subscription_repository.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Preferences": interested-in multi-select,
/// age range, max distance, and collapsible advanced filters (religion,
/// politics — free-form here; docs/03 notes no fixed value list exists yet).
///
/// Phase 2 item 2: the advanced filters are premium-gated
/// (docs/07 "Filters sheet": "advanced — gated to premium in Phase 2"). A
/// non-subscriber can still see and *remove* an already-set value (e.g. from
/// a lapsed subscription — the backend allows that, PreferenceController's
/// own doc comment explains why) but can't add a new one; the input is
/// locked instead, with a link straight to the Premium screen (item 1)
/// rather than the more elaborate dedicated paywall modal docs/07 describes
/// generically — a disclosed simplification, not a dropped screen.
///
/// Reused from the onboarding wizard (default: advances to Location; nothing
/// to pre-fill, this is the first time preferences are set) and the
/// standalone Edit preferences screen — a peer of Edit profile, not one of
/// its sections, per docs/07 §3.5's table — which passes [onDone] to pop back
/// and always has existing preferences to pre-fill.
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({
    this.onDone,
    this.continueLabel = 'Continue',
    this.step = 4,
    super.key,
  });

  final VoidCallback? onDone;
  final String continueLabel;
  final int? step;

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  bool _loading = true;
  RangeValues _ageRange = const RangeValues(21, 40);
  double _maxDistanceKm = 50;
  final Set<Gender> _interestedIn = {};
  final List<String> _religionFilter = [];
  final List<String> _politicsFilter = [];
  bool _hasAdvancedFilters = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = await ref.read(profileRepositoryProvider).getPreferences();
    final subscription = await ref
        .read(subscriptionRepositoryProvider)
        .getCurrent();
    if (!mounted) return;
    setState(() {
      if (existing != null) {
        _ageRange = RangeValues(
          existing.minAge.toDouble(),
          existing.maxAge.toDouble(),
        );
        _maxDistanceKm = existing.maxDistanceKm.toDouble();
        _interestedIn.addAll(existing.interestedInGenders);
        _religionFilter.addAll(existing.religionFilter);
        _politicsFilter.addAll(existing.politicsFilter);
      }
      _hasAdvancedFilters =
          subscription != null &&
          subscription.isActive &&
          subscription.plan.entitlementBool('advanced_filters');
      _loading = false;
    });
  }

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
      (widget.onDone ?? () => context.go('/onboarding/location'))();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return OnboardingScaffold(
        title: 'Preferences',
        step: widget.step,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return OnboardingScaffold(
      title: 'Preferences',
      step: widget.step,
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
                    () => selected
                        ? _interestedIn.add(gender)
                        : _interestedIn.remove(gender),
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
          Text(
            'Max distance: ${_maxDistanceKm.round()} km',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
            subtitle: _hasAdvancedFilters
                ? null
                : const Text('Premium feature'),
            children: [
              if (!_hasAdvancedFilters)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Upgrade to filter by religion or politics.',
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/settings/subscription'),
                        child: const Text('Upgrade'),
                      ),
                    ],
                  ),
                ),
              _ChipInput(
                label: 'Religion',
                values: _religionFilter,
                locked: !_hasAdvancedFilters,
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
                locked: !_hasAdvancedFilters,
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
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.continueLabel),
          ),
        ],
      ),
    );
  }
}

/// A free-text tag list — used for religion/politics since no fixed option
/// list exists anywhere in /docs (see docs/03-api-specification.md's note on
/// this).
///
/// [locked] (Phase 2 item 2) disables *adding* a new value without
/// disabling *removing* an existing one — the backend allows a non-
/// subscriber to clear a lapsed-subscription value but not add a new one
/// (PreferenceController's own doc comment), and the UI mirrors that
/// distinction rather than blocking the field outright.
class _ChipInput extends StatefulWidget {
  const _ChipInput({
    required this.label,
    required this.values,
    required this.onChanged,
    this.locked = false,
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final bool locked;

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
                enabled: !widget.locked,
                decoration: InputDecoration(labelText: widget.label),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: widget.locked ? null : _add,
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final value in widget.values)
              Chip(
                label: Text(value),
                onDeleted: () => widget.onChanged(
                  widget.values.where((v) => v != value).toList(),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
