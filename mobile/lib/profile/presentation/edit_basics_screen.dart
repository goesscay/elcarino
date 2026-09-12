import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
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
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final eighteenYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 18));
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? eighteenYearsAgo,
      firstDate: DateTime(1900),
      lastDate: eighteenYearsAgo,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _birthDate == null || _gender == null) {
      setState(() => _error = 'Fill in your name, date of birth, and gender to continue.');
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
            bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
            relationshipGoal: _relationshipGoalController.text.trim().isEmpty
                ? null
                : _relationshipGoalController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ValidationException catch (e) {
      setState(
        () => _error = e.firstError('birth_date') ?? e.firstError('display_name') ?? 'Check your details.',
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Basics & bio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'First name'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _birthDate == null
                              ? 'Date of birth'
                              : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
                        ),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: _pickBirthDate,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      RadioGroup<Gender>(
                        groupValue: _gender,
                        onChanged: (value) => setState(() => _gender = value),
                        child: Column(
                          children: [
                            for (final gender in Gender.values)
                              RadioListTile<Gender>(
                                contentPadding: EdgeInsets.zero,
                                title: Text(gender.label),
                                value: gender,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _bioController,
                        maxLength: 500,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Bio'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _relationshipGoalController,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: 'Relationship goal'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
