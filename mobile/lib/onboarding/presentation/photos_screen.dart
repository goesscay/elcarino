import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/network_photo.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Photos": "Grid of 6 slots, first is primary;
/// add from camera/library; drag to reorder; min 1 to continue [TBD]."
/// Reorder here is left/right buttons rather than drag — functionally
/// equivalent, simpler to implement correctly; real drag-and-drop is a hi-fi
/// interaction-design concern like the rest of docs/07 §4.5 motion/haptics.
///
/// Reused from both the onboarding wizard (default: advances to Prompts) and
/// the standalone Edit photos screen (docs/07 §3.5), which passes [onDone]
/// and [continueLabel] to pop back instead.
class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({
    this.onDone,
    this.continueLabel = 'Continue',
    this.step = 2,
    super.key,
  });

  final VoidCallback? onDone;
  final String continueLabel;
  final int? step;

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  static const _maxPhotos = 6;

  final _picker = ImagePicker();
  List<ProfilePhoto> _photos = [];
  bool _loading = true;
  bool _busy = false;
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
      _photos = profile?.photos ?? [];
      _loading = false;
    });
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (file == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await ref
          .read(profileRepositoryProvider)
          .uploadPhoto(file.path);
      setState(() => _photos = [..._photos, photo]);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto(ProfilePhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _error = null);
    try {
      await ref.read(profileRepositoryProvider).deletePhoto(photo.id);
      setState(() => _photos = _photos.where((p) => p.id != photo.id).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _move(int index, int delta) async {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _photos.length) return;

    final reordered = [..._photos];
    final item = reordered.removeAt(index);
    reordered.insert(newIndex, item);
    setState(() => _photos = reordered);

    try {
      await ref
          .read(profileRepositoryProvider)
          .reorderPhotos(reordered.map((p) => p.id).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return OnboardingScaffold(
        title: 'Photos',
        step: widget.step,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final text = Theme.of(context).textTheme;
    return OnboardingScaffold(
      title: 'Photos',
      step: widget.step,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add at least one photo — your first one is what people see '
            'first. You can add up to $_maxPhotos.',
            style: text.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.75,
              ),
              itemCount: _maxPhotos,
              itemBuilder: (context, index) {
                if (index < _photos.length) {
                  final photo = _photos[index];
                  return ProfilePhotoTile(
                    photo: photo,
                    isPrimary: index == 0,
                    onDelete: _busy ? null : () => _removePhoto(photo),
                    onMoveEarlier: (!_busy && index > 0)
                        ? () => _move(index, -1)
                        : null,
                    onMoveLater: (!_busy && index < _photos.length - 1)
                        ? () => _move(index, 1)
                        : null,
                  );
                }
                // Only the next empty slot invites an upload; the rest are
                // quiet placeholders, so the grid reads as "6 slots, filling
                // in order" rather than six competing buttons.
                return AddPhotoTile(
                  onTap: _busy ? null : _addPhoto,
                  prominent: index == _photos.length,
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _error!,
                style: text.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _photos.isEmpty
                ? null
                : (widget.onDone ?? () => context.go('/onboarding/prompts')),
            child: Text(widget.continueLabel),
          ),
        ],
      ),
    );
  }
}

/// One photo slot: the photo (rounded, top-biased crop), a "Main" badge on
/// the first, "Pending review" while moderation hasn't cleared it, a small
/// remove button, and a compact earlier/later control. Reordering stays as
/// buttons (not drag) — see [PhotosScreen]'s doc comment.
class ProfilePhotoTile extends StatelessWidget {
  const ProfilePhotoTile({
    required this.photo,
    required this.isPrimary,
    required this.onDelete,
    required this.onMoveEarlier,
    required this.onMoveLater,
    super.key,
  });

  final ProfilePhoto photo;
  final bool isPrimary;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveEarlier;
  final VoidCallback? onMoveLater;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          NetworkPhoto(photo.url),
          // Status badges sit just above the reorder controls (not beside the
          // remove button — on a narrow tile they'd collide with it).
          if (isPrimary || photo.moderationStatus == 'pending')
            Positioned(
              left: 6,
              bottom: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPrimary) const _PhotoBadge(label: 'Main'),
                  if (isPrimary && photo.moderationStatus == 'pending')
                    const SizedBox(height: 4),
                  if (photo.moderationStatus == 'pending')
                    const _PhotoBadge(label: 'In review'),
                ],
              ),
            ),
          Positioned(
            right: 6,
            top: 6,
            child: _PhotoControl(
              icon: Icons.close_rounded,
              label: 'Remove photo',
              onPressed: onDelete,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PhotoControl(
                  icon: Icons.chevron_left_rounded,
                  label: 'Move earlier',
                  onPressed: onMoveEarlier,
                ),
                const SizedBox(width: AppSpacing.xs),
                _PhotoControl(
                  icon: Icons.chevron_right_rounded,
                  label: 'Move later',
                  onPressed: onMoveLater,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small round control over a photo. Dimmed when unavailable rather than
/// hidden, so the layout doesn't shift between tiles.
class _PhotoControl extends StatelessWidget {
  const _PhotoControl({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: AppColors.photoControl,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(icon, color: AppColors.onPhoto, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.photoControl,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.onPhoto, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// An empty slot. [prominent] (the next slot to fill) is a tinted, labelled
/// invitation; the others are quiet outlines.
class AddPhotoTile extends StatelessWidget {
  const AddPhotoTile({required this.onTap, this.prominent = false, super.key});

  final VoidCallback? onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Add photo',
      excludeSemantics: true,
      child: Material(
        color: prominent ? p.primaryTint : p.fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 28,
                  color: prominent ? AppColors.primary : p.textSecondary,
                ),
                if (prominent) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Add photo',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
