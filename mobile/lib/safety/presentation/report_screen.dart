import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../data/safety_repository.dart';
import '../domain/report_category.dart';

/// docs/07-ui-ux-design.md §3.7's "Report — category" and "Report — detail"
/// as two steps of one screen rather than two separately routed screens —
/// a disclosed simplification for what's fundamentally one linear form, same
/// spirit as other screens in this app that trade a wireframe's exact
/// screen-per-step breakdown for one screen with internal steps.
/// "Report — confirmation" is a `SnackBar` on the screen this pops back to,
/// not its own screen. Evidence attachment ("attach which messages/photos")
/// isn't built — the `reports` schema has no column for it.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({
    required this.userId,
    required this.displayName,
    super.key,
  });

  final int userId;
  final String displayName;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _descriptionController = TextEditingController();

  ReportCategory? _category;
  bool _alsoBlock = false;
  bool _submitting = false;

  void _selectCategory(ReportCategory category) {
    setState(() => _category = category);
  }

  Future<void> _submit() async {
    final category = _category;
    if (category == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .report(
            userId: widget.userId,
            category: category,
            description: _descriptionController.text.trim(),
            alsoBlock: _alsoBlock,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — our team will review this.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    return Scaffold(
      appBar: AppBar(title: Text('Report ${widget.displayName}')),
      body: SafeArea(
        child: category == null
            ? _buildCategoryStep()
            : _buildDetailStep(category),
      ),
    );
  }

  Widget _buildCategoryStep() {
    return ListView(
      children: [
        for (final category in ReportCategory.values)
          ListTile(
            title: Text(category.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectCategory(category),
          ),
      ],
    );
  }

  Widget _buildDetailStep(ReportCategory category) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(category.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Tell us more (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          CheckboxListTile(
            value: _alsoBlock,
            onChanged: (value) => setState(() => _alsoBlock = value ?? false),
            title: const Text('Also block this person'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _submitting
                ? null
                : () => setState(() => _category = null),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
