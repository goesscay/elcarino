import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../data/auth_repository.dart';

/// docs/07-ui-ux-design.md §3.1 "Email / phone entry" (phone variant):
/// "Single field; country-code picker for phone; Continue. Validation
/// inline." The picker here is a short list covering the launch markets
/// (docs/00 quick facts: Malaysia -> Maldives -> India) plus a couple of
/// common fallbacks — not a full ISO-3166 list, which belongs with the hi-fi
/// design pass, not this wireframe-equivalent implementation.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  static const _countryCodes = [
    ('+60', 'Malaysia'),
    ('+960', 'Maldives'),
    ('+91', 'India'),
    ('+1', 'Other (+1)'),
    ('+44', 'Other (+44)'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _countryCode = _countryCodes.first.$1;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final phone = '$_countryCode${_phoneController.text.trim()}';

    try {
      await ref.read(authRepositoryProvider).requestOtp(phone: phone);
      if (!mounted) return;
      unawaited(context.push('/auth/otp', extra: phone));
    } on ValidationException catch (e) {
      setState(() => _error = e.firstError('phone') ?? 'Enter a valid phone number.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your phone number')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<String>(
                    value: _countryCode,
                    items: [
                      for (final (code, label) in _countryCodes)
                        DropdownMenuItem(value: code, child: Text('$code  $label')),
                    ],
                    onChanged: (value) => setState(() => _countryCode = value!),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Phone number'),
                      validator: (value) =>
                          (value == null || value.trim().length < 6) ? 'Enter a valid number' : null,
                    ),
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
