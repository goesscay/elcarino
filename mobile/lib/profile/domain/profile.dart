import 'gender.dart';

class ProfilePhoto {
  const ProfilePhoto({
    required this.id,
    required this.url,
    required this.sortOrder,
    required this.moderationStatus,
  });

  factory ProfilePhoto.fromJson(Map<String, dynamic> json) => ProfilePhoto(
    id: json['id'] as int,
    url: json['url'] as String,
    sortOrder: json['sort_order'] as int,
    moderationStatus: json['moderation_status'] as String,
  );

  final int id;
  final String url;
  final int sortOrder;
  final String moderationStatus;
}

class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.birthDate,
    required this.gender,
    required this.bio,
    required this.relationshipGoal,
    required this.religion,
    required this.politics,
    required this.isVerified,
    required this.completionPct,
    required this.photos,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as int,
    displayName: json['display_name'] as String,
    birthDate: DateTime.parse(json['birth_date'] as String),
    gender: Gender.fromApiValue(json['gender'] as String),
    bio: json['bio'] as String?,
    relationshipGoal: json['relationship_goal'] as String?,
    // Phase 2 item 2 — the viewer's own value. Owner-only in the API
    // response (ProfileResource's own doc comment); never present on
    // another user's profile.
    religion: json['religion'] as String?,
    politics: json['politics'] as String?,
    isVerified: json['is_verified'] as bool,
    completionPct: json['completion_pct'] as int,
    photos: (json['photos'] as List<dynamic>? ?? [])
        .map((e) => ProfilePhoto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final int id;
  final String displayName;
  final DateTime birthDate;
  final Gender gender;
  final String? bio;
  final String? relationshipGoal;
  final String? religion;
  final String? politics;
  final bool isVerified;
  final int completionPct;
  final List<ProfilePhoto> photos;
}
