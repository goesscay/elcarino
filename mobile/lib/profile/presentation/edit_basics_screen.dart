import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/section_row.dart';
import '../data/profile_repository.dart';
import '../domain/gender.dart';

/// Covers three of docs/07-ui-ux-design.md §3.5 "Edit profile" sections
/// (bio, basics, relationship goal) in one screen — see edit_profile_screen's
/// doc comment for why they're combined rather than three single-field ones.
class EditBasicsScreen extends ConsumerStatefulWidget {
  const EditBasicsScreen({super.key});

  @override
  ConsumerState<EditBasicsScreen> createState() => _EditBasicsScreenState();
}

class _EditBasicsScreenState extends ConsumerState<EditBasicsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _relationshipGoalController = TextEditingController();
  final _religionController = TextEditingController();
  final _politicsController = TextEditingController();
  DateTime? _birthDate;
  Gender? _gender;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(profileRepositoryProvider).getProfile();
    if (!mounted) return;
    setState(() {
      if (profile != null) {
        _nameController.text = profile.displayName;
        _bioController.text = profile.bio ?? '';
        _relationshipGoalController.text = profile.relationshipGoal ?? '';
        _religionController.text = profile.religion ?? '';
        _politicsController.text = profile.politics ?? '';
        _birthDate = profile.birthDate;
        _gender = profile.gender;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _relationshipGoalController.dispose();
    _religionController.dispose();
    _politicsController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final eighteenYearsAgo = DateTime.now().subtract(
      const Duration(days: 365 * 18),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? eighteenYearsAgo,
      firstDate: DateTime(1900),
      lastDate: eighteenYearsAgo,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _birthDate == null ||
        _gender == null) {
      setState(
        () => _error =
            'Fill in your name, date of birth, and gender to continue.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfileBasics(
            displayName: _nameController.text.trim(),
            birthDate: _birthDate!,
            gender: _gender!,
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            relationshipGoal: _relationshipGoalController.text.trim().isEmpty
                ? null
                : _relationshipGoalController.text.trim(),
            religion: _religionController.text.trim().isEmpty
                ? null
                : _religionController.text.trim(),
            politics: _politicsController.text.trim().isEmpty
                ? null
                : _politicsController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ValidationException catch (e) {
      setState(
        () => _error =
            e.firstError('birth_date') ??
            e.firstError('display_name') ??
            'Check your details.',
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Basics & bio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screen,
                          0,
                          AppSpacing.screen,
                          AppSpacing.lg,
                        ),
                        children: [
                          const SectionHeading('Basic information'),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'First name',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Enter your name'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          InkWell(
                            onTap: _pickBirthDate,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date of birth',
                                suffixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                _birthDate == null
                                    ? 'Select'
                                    : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: _birthDate == null
                                          ? p.textSecondary
                                          : null,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Gender',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: p.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final gender in Gender.values)
                                ChoiceChip(
                                  label: Text(gender.label),
                                  selected: _gender == gender,
                                  onSelected: (_) =>
                                      setState(() => _gender = gender),
                                ),
                            ],
                          ),
                          const SectionHeading('About me'),
                          TextFormField(
                            controller: _bioController,
                            maxLength: 500,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Bio',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SectionHeading('Relationship goal'),
                          TextFormField(
                            controller: _relationshipGoalController,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'What are you looking for?',
                            ),
                          ),
                          // Phase 2 item 2 — feeds the (premium-gated) advanced
                          // filters in Edit preferences; free for anyone to set
                          // on their own profile, same as bio/relationship goal.
                          const SectionHeading(
                            'Optional',
                            hint: 'Used for the advanced filters.',
                          ),
                          TextFormField(
                            controller: _religionController,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'Religion',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _politicsController,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'Politics',
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _error!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.danger),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // The Save button stays pinned below the scrolling form,
                    // always reachable however long the form gets.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        AppSpacing.sm,
                        AppSpacing.screen,
                        AppSpacing.lg,
                      ),
                      child: FilledButton(
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
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
