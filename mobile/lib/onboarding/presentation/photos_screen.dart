import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile.dart';
import 'onboarding_scaffold.dart';

/// docs/07-ui-ux-design.md §3.1 "Photos": "Grid of 6 slots, first is primary;
/// add from camera/library; drag to reorder; min 1 to continue [TBD]."
/// Reorder here is left/right buttons rather than drag — functionally
/// equivalent, simpler to implement correctly; real drag-and-drop is a hi-fi
/// interaction-design concern like the rest of docs/07 §4.5 motion/haptics.
class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

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
      final photo = await ref.read(profileRepositoryProvider).uploadPhoto(file.path);
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
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
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
      await ref.read(profileRepositoryProvider).reorderPhotos(reordered.map((p) => p.id).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const OnboardingScaffold(
        title: 'Photos',
        step: 2,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return OnboardingScaffold(
      title: 'Photos',
      step: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add at least one photo. The first is your primary photo.'),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
              ),
              itemCount: _maxPhotos,
              itemBuilder: (context, index) {
                if (index < _photos.length) {
                  final photo = _photos[index];
                  return _PhotoTile(
                    photo: photo,
                    isPrimary: index == 0,
                    onDelete: _busy ? null : () => _removePhoto(photo),
                    onMoveLeft: (!_busy && index > 0) ? () => _move(index, -1) : null,
                    onMoveRight: (!_busy && index < _photos.length - 1) ? () => _move(index, 1) : null,
                  );
                }
                return _AddTile(onTap: _busy ? null : _addPhoto);
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _photos.isEmpty ? null : () => context.go('/onboarding/prompts'),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.isPrimary,
    required this.onDelete,
    required this.onMoveLeft,
    required this.onMoveRight,
  });

  final ProfilePhoto photo;
  final bool isPrimary;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(photo.url, fit: BoxFit.cover),
          if (isPrimary)
            const Positioned(
              left: 4,
              top: 4,
              child: _Badge(label: 'Primary'),
            ),
          if (photo.moderationStatus == 'pending')
            const Positioned(
              left: 4,
              bottom: 4,
              child: _Badge(label: 'Pending review'),
            ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: onDelete,
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
                  onPressed: onMoveLeft,
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                  onPressed: onMoveRight,
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: DottedBorderBox(child: const Icon(Icons.add_a_photo_outlined)),
    );
  }
}

/// A plain dashed-look placeholder box — no extra package for one border
/// style.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Center(child: child),
    );
  }
}
