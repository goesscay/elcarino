import '../../discovery/domain/candidate.dart';

/// One Explore tile (`GET /explore/interests`, docs/03 "Explore"): an interest
/// and how many people the viewer could actually be shown who share it.
class ExploreInterest {
  const ExploreInterest({
    required this.id,
    required this.name,
    required this.category,
    required this.memberCount,
    required this.isYours,
  });

  factory ExploreInterest.fromJson(Map<String, dynamic> json) =>
      ExploreInterest(
        id: json['id'] as int,
        name: json['name'] as String,
        category: json['category'] as String?,
        memberCount: json['member_count'] as int,
        isYours: json['is_yours'] as bool,
      );

  final int id;
  final String name;
  final String? category;
  final int memberCount;

  /// The viewer has this interest on their own profile.
  final bool isYours;

  String get peopleLabel =>
      memberCount == 1 ? '1 person' : '$memberCount people';
}

/// One page of `GET /explore/interests/{id}/people`.
class ExplorePeoplePage {
  const ExplorePeoplePage({
    required this.people,
    required this.total,
    required this.hasMore,
  });

  factory ExplorePeoplePage.fromJson(Map<String, dynamic> json) =>
      ExplorePeoplePage(
        people: (json['people'] as List<dynamic>)
            .map((e) => DiscoveryCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        hasMore: (json['meta'] as Map<String, dynamic>)['has_more'] as bool,
      );

  final List<DiscoveryCandidate> people;
  final int total;
  final bool hasMore;
}
