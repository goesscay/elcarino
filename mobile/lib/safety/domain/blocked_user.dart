import '../../profile/domain/profile.dart';

/// Mirrors the backend's `BlockedUserResource` (docs/03-api-specification.md
/// "Safety"). Deliberately null-safe on every field beyond `id` — you can
/// block/report any user id, not just someone with a completed profile, so
/// unlike `MatchedUser` this can't assume one exists.
class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.displayName,
    required this.photo,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
    id: json['id'] as int,
    displayName: json['display_name'] as String?,
    photo: json['photo'] == null
        ? null
        : ProfilePhoto.fromJson(json['photo'] as Map<String, dynamic>),
  );

  final int id;
  final String? displayName;
  final ProfilePhoto? photo;
}
