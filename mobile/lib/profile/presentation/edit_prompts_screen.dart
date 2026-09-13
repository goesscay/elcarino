import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../data/profile_repository.dart';
import '../domain/prompt.dart';

/// docs/07-ui-ux-design.md §3.5 "Edit prompts": "Reorder answered prompts;
/// swap a prompt; edit an answer." Distinct from onboarding's Prompts screen
/// (§3.1, "pick 3 from the library") — that one is a first-time picker; this
/// one manages prompts you've already answered. Phase 1 item 4's remaining
/// scope, per docs/04: reordering, since library+answer already existed.
///
/// Reorder persists via the same full-replace `PUT /prompts/me` every other
/// prompt mutation already used (resubmitting in the new order sets
/// `sort_order`) — no new backend endpoint needed. Swap/edit/remove use the
/// existing add/update/delete-one-answer contract.
class EditPromptsScreen extends ConsumerStatefulWidget {
  const EditPromptsScreen({super.key});

  @override
  ConsumerState<EditPromptsScreen> createState() => _EditPromptsScreenState();
}

class _EditPromptsScreenState extends ConsumerState<EditPromptsScreen> {
  static const _maxPrompts = 3; // matches the onboarding Prompts screen's cap
  static const _answerMaxLength = 300;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<AnsweredPrompt> _answered = [];
  List<PromptLibraryItem> _library = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repository = ref.read(profileRepositoryProvider);
      final library = await repository.getPromptLibrary();
      final mine = await repository.getMyPrompts();
      if (!mounted) return;
      setState(() {
        _library = library;
        _answered = mine;
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

  Future<void> _persist() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updatePrompts([
        for (final prompt in _answered) (prompt.promptId, prompt.answer),
      ]);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // onReorderItem (not the deprecated onReorder) already adjusts newIndex
  // for the removed item, so no manual `if (newIndex > oldIndex) newIndex--`
  // correction is needed here.
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _answered.removeAt(oldIndex);
      _answered.insert(newIndex, item);
    });
    _persist();
  }

  Future<String?> _promptForAnswer({
    required String title,
    String initialValue = '',
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: _answerMaxLength,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editAnswer(AnsweredPrompt prompt) async {
    final answer = await _promptForAnswer(
      title: prompt.promptText,
      initialValue: prompt.answer,
    );
    if (answer == null || answer.isEmpty) return;

    setState(() {
      final index = _answered.indexWhere((a) => a.promptId == prompt.promptId);
      _answered[index] = AnsweredPrompt(
        promptId: prompt.promptId,
        promptText: prompt.promptText,
        answer: answer,
      );
    });
    await _persist();
  }

  Future<void> _remove(AnsweredPrompt prompt) async {
    setState(() => _answered.removeWhere((a) => a.promptId == prompt.promptId));
    try {
      await ref
          .read(profileRepositoryProvider)
          .deletePromptAnswer(prompt.promptId);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _addPrompt() async {
    final available = _library
        .where((p) => !_answered.any((a) => a.promptId == p.id))
        .toList();
    if (available.isEmpty) return;

    final chosen = await showModalBottomSheet<PromptLibraryItem>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final prompt in available)
              ListTile(
                title: Text(prompt.prompt),
                onTap: () => Navigator.pop(sheetContext, prompt),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;

    final answer = await _promptForAnswer(title: chosen.prompt);
    if (answer == null || answer.isEmpty) return;

    setState(
      () => _answered.add(
        AnsweredPrompt(
          promptId: chosen.id,
          promptText: chosen.prompt,
          answer: answer,
        ),
      ),
    );
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prompts')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Prompts')),
      floatingActionButton: (_answered.length >= _maxPrompts || _busy)
          ? null
          : FloatingActionButton(
              onPressed: _addPrompt,
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: _answered.isEmpty
                  ? const Center(
                      child: Text('No prompts answered yet. Tap + to add one.'),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _answered.length,
                      onReorderItem: _busy ? (_, _) {} : _onReorder,
                      itemBuilder: (context, index) {
                        final prompt = _answered[index];
                        return Card(
                          key: ValueKey(prompt.promptId),
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            title: Text(prompt.promptText),
                            subtitle: Text(prompt.answer),
                            onTap: _busy ? null : () => _editAnswer(prompt),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _busy ? null : () => _remove(prompt),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
