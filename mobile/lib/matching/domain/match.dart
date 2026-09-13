import '../../profile/domain/profile.dart';

/// The other participant's public profile projection inside a match —
/// same shape as a discovery candidate, minus `distance_km` (matches aren't
/// distance-scoped). See the backend's MatchedUserResource.
class MatchedUser {
  const MatchedUser({
    required this.id,
    required this.displayName,
    required this.age,
    required this.bio,
    required this.isVerified,
    required this.photos,
  });

  factory MatchedUser.fromJson(Map<String, dynamic> json) => MatchedUser(
    id: json['id'] as int,
    displayName: json['display_name'] as String,
    age: json['age'] as int,
    bio: json['bio'] as String?,
    isVerified: json['is_verified'] as bool,
    photos: (json['photos'] as List<dynamic>)
        .map((e) => ProfilePhoto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final int id;
  final String displayName;
  final int age;
  final String? bio;
  final bool isVerified;
  final List<ProfilePhoto> photos;
}

class UserMatch {
  const UserMatch({
    required this.id,
    required this.otherUser,
    required this.matchedAt,
    required this.unmatchedAt,
  });

  factory UserMatch.fromJson(Map<String, dynamic> json) => UserMatch(
    id: json['id'] as int,
    otherUser: MatchedUser.fromJson(json['other_user'] as Map<String, dynamic>),
    matchedAt: DateTime.parse(json['matched_at'] as String),
    unmatchedAt: json['unmatched_at'] == null
        ? null
        : DateTime.parse(json['unmatched_at'] as String),
  );

  final int id;
  final MatchedUser otherUser;
  final DateTime matchedAt;
  final DateTime? unmatchedAt;

  bool get isActive => unmatchedAt == null;
}
