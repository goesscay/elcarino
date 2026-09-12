import 'gender.dart';

class Preferences {
  const Preferences({
    required this.minAge,
    required this.maxAge,
    required this.maxDistanceKm,
    required this.interestedInGenders,
    this.religionFilter = const [],
    this.politicsFilter = const [],
    this.relationshipGoalFilter = const [],
  });

  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
    minAge: json['min_age'] as int,
    maxAge: json['max_age'] as int,
    maxDistanceKm: json['max_distance_km'] as int,
    interestedInGenders: (json['interested_in_genders'] as List<dynamic>)
        .map((e) => Gender.fromApiValue(e as String))
        .toList(),
    religionFilter: List<String>.from(json['religion_filter'] as List<dynamic>? ?? []),
    politicsFilter: List<String>.from(json['politics_filter'] as List<dynamic>? ?? []),
    relationshipGoalFilter: List<String>.from(
      json['relationship_goal_filter'] as List<dynamic>? ?? [],
    ),
  );

  final int minAge;
  final int maxAge;
  final int maxDistanceKm;
  final List<Gender> interestedInGenders;
  final List<String> religionFilter;
  final List<String> politicsFilter;
  final List<String> relationshipGoalFilter;

  Map<String, dynamic> toJson() => {
    'min_age': minAge,
    'max_age': maxAge,
    'max_distance_km': maxDistanceKm,
    'interested_in_genders': interestedInGenders.map((g) => g.apiValue).toList(),
    'religion_filter': religionFilter,
    'politics_filter': politicsFilter,
    'relationship_goal_filter': relationshipGoalFilter,
  };
}
