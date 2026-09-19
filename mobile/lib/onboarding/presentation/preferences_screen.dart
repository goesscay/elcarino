import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/gender.dart';
import '../../profile/domain/preferences.dart';
import '../../subscriptions/data/subscription_repository.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Preferences" and §3.2 "Filters sheet":
/// interested-in multi-select, age range, max distance, and collapsible
/// advanced filters (religion, politics — free-form here; docs/03 notes no
/// fixed value list exists yet).
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
/// Reused from three places, all the same form: the onboarding wizard
/// (default: advances to Location; nothing to pre-fill), the standalone Edit
/// preferences screen (a peer of Edit profile per docs/07 §3.5), and Discover's
/// Filters entry (`/discover/filters`, "Show people"). The latter two pass
/// [onDone] to pop back and always have existing preferences to pre-fill.
///
/// **Reset** appears once the form differs from what was loaded, and puts it
/// back exactly as loaded — the saved preferences, or the starting defaults on
/// first setup. It only reverts unsaved edits; it never clears saved data and
/// invents no "default" filter values.
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({
    this.onDone,
    this.continueLabel = 'Continue',
    this.title = 'Preferences',
    this.step = 4,
    super.key,
  });

  final VoidCallback? onDone;
  final String continueLabel;
  final String title;
  final int? step;

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

/// The editable state of the form, comparable so "has anything changed" and
/// "put it back" are one idea.
@immutable
class _FormState {
  const _FormState({
    required this.ageRange,
    required this.maxDistanceKm,
    required this.interestedIn,
    required this.religion,
    required this.politics,
  });

  final RangeValues ageRange;
  final double maxDistanceKm;
  final Set<Gender> interestedIn;
  final List<String> religion;
  final List<String> politics;

  @override
  bool operator ==(Object other) =>
      other is _FormState &&
      other.ageRange == ageRange &&
      other.maxDistanceKm == maxDistanceKm &&
      setEquals(other.interestedIn, interestedIn) &&
      listEquals(other.religion, religion) &&
      listEquals(other.politics, politics);

  @override
  int get hashCode => Object.hash(
    ageRange,
    maxDistanceKm,
    Object.hashAllUnordered(interestedIn),
    Object.hashAll(religion),
    Object.hashAll(politics),
  );
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

  /// What the form looked like when it finished loading.
  _FormState? _baseline;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _FormState _current() => _FormState(
    ageRange: _ageRange,
    maxDistanceKm: _maxDistanceKm,
    interestedIn: {..._interestedIn},
    religion: [..._religionFilter],
    politics: [..._politicsFilter],
  );

  bool get _dirty => _baseline != null && _current() != _baseline;

  void _reset() {
    final b = _baseline;
    if (b == null) return;
    setState(() {
      _ageRange = b.ageRange;
      _maxDistanceKm = b.maxDistanceKm;
      _interestedIn
        ..clear()
        ..addAll(b.interestedIn);
      _religionFilter
        ..clear()
        ..addAll(b.religion);
      _politicsFilter
        ..clear()
        ..addAll(b.politics);
      _error = null;
    });
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
      _baseline = _current();
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
        title: widget.title,
        step: widget.step,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return OnboardingScaffold(
      title: widget.title,
      step: widget.step,
      actions: [
        if (_dirty) TextButton(onPressed: _reset, child: const Text('Reset')),
        const SizedBox(width: AppSpacing.sm),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text('Interested in', style: text.headlineSmall),
                ),
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
                _LabelledValue(
                  label: 'Age range',
                  value:
                      '${_ageRange.start.round()} – ${_ageRange.end.round()}',
                ),
                RangeSlider(
                  values: _ageRange,
                  min: 18,
                  max: 100,
                  divisions: 82,
                  onChanged: (values) => setState(() => _ageRange = values),
                ),
                _LabelledValue(
                  label: 'Distance',
                  value: '${_maxDistanceKm.round()} km',
                ),
                Slider(
                  value: _maxDistanceKm,
                  min: 1,
                  max: 200,
                  divisions: 199,
                  onChanged: (value) => setState(() => _maxDistanceKm = value),
                ),
                const SizedBox(height: AppSpacing.xl),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    title: Row(
                      children: [
                        Text('Advanced filters', style: text.titleMedium),
                        if (!_hasAdvancedFilters) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const _PremiumPill(),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      'Religion and politics',
                      style: text.bodySmall,
                    ),
                    children: [
                      if (!_hasAdvancedFilters)
                        Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.only(
                            left: AppSpacing.md,
                            top: AppSpacing.xs,
                            bottom: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: p.primaryTint,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Upgrade to filter by religion or politics.',
                                  style: text.bodyMedium,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    context.push('/settings/subscription'),
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
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: text.bodyMedium?.copyWith(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
          // The primary action stays pinned below the scrolling form.
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Text(widget.continueLabel),
          ),
        ],
      ),
    );
  }
}

/// "Age range ........ 22 – 38": a label with its live value in brand red.
class _LabelledValue extends StatelessWidget {
  const _LabelledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.headlineSmall)),
          Text(
            value,
            style: text.titleMedium?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _PremiumPill extends StatelessWidget {
  const _PremiumPill();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              'Premium',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add ${widget.label.toLowerCase()} filter',
              onPressed: widget.locked ? null : _add,
            ),
          ],
        ),
        if (widget.values.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
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
          ),
      ],
    );
  }
}
