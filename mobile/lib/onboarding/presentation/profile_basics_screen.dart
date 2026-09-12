import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/gender.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Profile basics": first name, date of birth
/// (18+ enforced — decision #4), gender (decision #6). Progress 1/5.
class ProfileBasicsScreen extends ConsumerStatefulWidget {
  const ProfileBasicsScreen({super.key});

  @override
  ConsumerState<ProfileBasicsScreen> createState() => _ProfileBasicsScreenState();
}

class _ProfileBasicsScreenState extends ConsumerState<ProfileBasicsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _birthDate;
  Gender? _gender;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isAtLeast18 {
    final date = _birthDate;
    if (date == null) return false;
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
      age -= 1;
    }
    return age >= 18;
  }

  Future<void> _pickBirthDate() async {
    final eighteenYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 18));
    final picked = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
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
          );
      if (!mounted) return;
      context.go('/onboarding/photos');
    } on ValidationException catch (e) {
      setState(() => _error = e.firstError('birth_date') ?? e.firstError('display_name') ?? 'Check your details.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Profile basics',
      step: 1,
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'First name'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_birthDate == null ? 'Date of birth' : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickBirthDate,
            ),
            if (_birthDate != null && !_isAtLeast18)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'You must be at least 18 to use Elcarino.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text('Gender', style: Theme.of(context).textTheme.bodyMedium),
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
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: (_submitting || (_birthDate != null && !_isAtLeast18)) ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
