import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/prompt.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Prompts": "Pick 3 prompts from the library,
/// answer each (char limit). Skippable? [TBD — recommend: require 1]."
/// Enforces the client-side "require at least 1" recommendation; the server
/// enforces the max of 3 (config/media.php on the backend).
///
/// Reused from the onboarding wizard (default: advances to Preferences) and
/// the standalone Edit prompts screen, which passes [onDone]/[continueLabel]
/// to pop back instead. Drag-to-reorder answered prompts (docs/07 §3.5) is
/// item 4's scope, not built here yet.
class PromptsScreen extends ConsumerStatefulWidget {
  const PromptsScreen({this.onDone, this.continueLabel = 'Continue', this.step = 3, super.key});

  final VoidCallback? onDone;
  final String continueLabel;
  final int? step;

  @override
  ConsumerState<PromptsScreen> createState() => _PromptsScreenState();
}

class _PromptsScreenState extends ConsumerState<PromptsScreen> {
  static const _maxPrompts = 3;
  static const _answerMaxLength = 300;

  bool _loading = true;
  String? _error;
  bool _submitting = false;
  List<PromptLibraryItem> _library = [];
  final Map<int, TextEditingController> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _selected.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repository = ref.read(profileRepositoryProvider);
      final library = await repository.getPromptLibrary();
      final mine = await repository.getMyPrompts();
      if (!mounted) return;
      setState(() {
        _library = library;
        for (final answered in mine) {
          _selected[answered.promptId] = TextEditingController(text: answered.answer);
        }
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

  void _toggle(PromptLibraryItem prompt, bool selected) {
    setState(() {
      if (selected) {
        if (_selected.length >= _maxPrompts) return;
        _selected[prompt.id] = TextEditingController();
      } else {
        _selected.remove(prompt.id)?.dispose();
      }
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Answer at least one prompt to continue.');
      return;
    }
    if (_selected.values.any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'Fill in every prompt you picked, or remove it.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(profileRepositoryProvider)
          .updatePrompts([
            for (final entry in _selected.entries) (entry.key, entry.value.text.trim()),
          ]);
      if (!mounted) return;
      (widget.onDone ?? () => context.go('/onboarding/preferences'))();
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
        title: 'Prompts',
        step: widget.step,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return OnboardingScaffold(
      title: 'Prompts',
      step: widget.step,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pick up to $_maxPrompts prompts and answer them (${_selected.length}/$_maxPrompts selected).'),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.builder(
              itemCount: _library.length,
              itemBuilder: (context, index) {
                final prompt = _library[index];
                final isSelected = _selected.containsKey(prompt.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(prompt.prompt),
                          value: isSelected,
                          onChanged: (_selected.length >= _maxPrompts && !isSelected)
                              ? null
                              : (value) => _toggle(prompt, value ?? false),
                        ),
                        if (isSelected)
                          TextField(
                            controller: _selected[prompt.id],
                            maxLength: _answerMaxLength,
                            maxLines: 3,
                            decoration: const InputDecoration(hintText: 'Your answer'),
                          ),
                      ],
                    ),
                  ),
                );
              },
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.continueLabel),
          ),
        ],
      ),
    );
  }
}
