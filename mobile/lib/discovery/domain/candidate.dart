import '../../profile/domain/profile.dart';
import '../../profile/domain/prompt.dart';

/// The "public profile projection" returned by `GET /discovery/feed`
/// (docs/03-api-specification.md). Narrower than [Profile] on purpose — no
/// `completion_pct`, no raw location, nothing an owner-only view would show.
class DiscoveryCandidate {
  const DiscoveryCandidate({
    required this.id,
    required this.displayName,
    required this.age,
    required this.bio,
    required this.relationshipGoal,
    required this.isVerified,
    required this.distanceKm,
    required this.sharedInterestsCount,
    required this.sharedInterests,
    required this.photos,
    this.interests = const [],
    this.prompts = const [],
    this.likedAt,
  });

  factory DiscoveryCandidate.fromJson(
    Map<String, dynamic> json,
  ) => DiscoveryCandidate(
    id: json['id'] as int,
    displayName: json['display_name'] as String,
    age: json['age'] as int,
    bio: json['bio'] as String?,
    relationshipGoal: json['relationship_goal'] as String?,
    isVerified: json['is_verified'] as bool,
    // Null only where the viewer or this person never shared a location —
    // never in the feed itself, which requires both, but possible on the
    // Likes lists.
    distanceKm: json['distance_km'] as int?,
    // Phase 1 item 7 (Matching engine v1) — a plain, transparent count/name
    // list the feed is now ranked by, never a hidden "compatibility score"
    // (spec §10 explicitly forbids hardcoding one in Phase 1). Parsed here
    // for forward-compatibility; docs/07's Card-stack wireframe doesn't call
    // for surfacing it visually, so there's no UI for it yet.
    sharedInterestsCount: json['shared_interests_count'] as int,
    sharedInterests: List<String>.from(
      json['shared_interests'] as List<dynamic>,
    ),
    photos: (json['photos'] as List<dynamic>)
        .map((e) => ProfilePhoto.fromJson(e as Map<String, dynamic>))
        .toList(),
    interests: List<String>.from(
      json['interests'] as List<dynamic>? ?? const [],
    ),
    prompts: (json['prompts'] as List<dynamic>? ?? const [])
        .map((e) => AnsweredPrompt.fromJson(e as Map<String, dynamic>))
        .toList(),
    likedAt: json['liked_at'] == null
        ? null
        : DateTime.parse(json['liked_at'] as String),
  );

  final int id;
  final String displayName;
  final int age;
  final String? bio;
  final String? relationshipGoal;
  final bool isVerified;
  final int? distanceKm;
  final int sharedInterestsCount;
  final List<String> sharedInterests;
  final List<ProfilePhoto> photos;

  /// Every interest (the detail screen shows them all); [sharedInterests] is
  /// the subset the viewer also has.
  final List<String> interests;
  final List<AnsweredPrompt> prompts;

  /// Only set on the Likes lists: when the like happened.
  final DateTime? likedAt;

  /// docs/06-security-architecture.md §4: `0` is the sentinel for "less than
  /// 1 km away" — the API never sends a raw float, this is the client-side
  /// half of that same bucketing rule (see the backend's DistanceBucketer).
  ///
  /// Null when there's no distance to show.
  String? get distanceLabel {
    final km = distanceKm;
    if (km == null) return null;
    return km == 0 ? 'less than 1 km away' : '$km km away';
  }
}
