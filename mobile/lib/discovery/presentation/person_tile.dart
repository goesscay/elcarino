import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/network_photo.dart';
import '../domain/candidate.dart';

/// One person in a photo grid (Likes, Explore): the photo, and name + age and
/// distance over a soft bottom fade. Tapping it is the caller's business.
class PersonTile extends StatelessWidget {
  const PersonTile({required this.candidate, required this.onTap, super.key});

  final DiscoveryCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final distance = candidate.shortDistanceLabel;
    final photos = candidate.photos;
    return Semantics(
      button: true,
      label: '${candidate.displayName}, ${candidate.age}. Open profile',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              photos.isEmpty
                  ? const PhotoPlaceholder()
                  : NetworkPhoto(photos.first.url),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.photoScrimClear, AppColors.photoScrim],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${candidate.displayName}, ${candidate.age}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        color: AppColors.onPhoto,
                      ),
                    ),
                    if (distance != null)
                      Text(
                        distance,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.onPhotoMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
