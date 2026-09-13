import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/device/device_name.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../data/auth_repository.dart';
import '../domain/auth_intent.dart';

/// docs/07-ui-ux-design.md §3.1 "Email / phone entry" (email variant). The
/// backend's register/login both require a password (docs/03 Auth group), so
/// unlike the phone/OTP path this collects one — which call to make is
/// decided by [intent], set from the Welcome screen's two buttons.
class EmailEntryScreen extends ConsumerStatefulWidget {
  const EmailEntryScreen({required this.intent, super.key});

  final AuthIntent intent;

  @override
  ConsumerState<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends ConsumerState<EmailEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _emailError;
  String? _passwordError;
  String? _formError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _emailError = null;
      _passwordError = null;
      _formError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final repository = ref.read(authRepositoryProvider);
      final result = widget.intent == AuthIntent.register
          ? await repository.register(
              email: email,
              password: password,
              deviceName: currentDeviceName(),
            )
          : await repository.loginWithEmail(
              email: email,
              password: password,
              deviceName: currentDeviceName(),
            );

      await ref.read(authControllerProvider.notifier).signedIn(result.token);
      if (!mounted) return;
      context.go('/');
    } on ValidationException catch (e) {
      setState(() {
        _emailError = e.firstError('email');
        _passwordError = e.firstError('password');
      });
    } on ApiException catch (e) {
      setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.intent == AuthIntent.register
              ? 'Create your account'
              : 'Sign in',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: _emailError,
                ),
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _passwordError,
                ),
                validator: (value) => (value == null || value.length < 8)
                    ? 'At least 8 characters'
                    : null,
              ),
              if (_formError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _formError!,
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
                    : Text(
                        widget.intent == AuthIntent.register
                            ? 'Create account'
                            : 'Sign in',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
