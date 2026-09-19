import 'package:datingapp/discovery/domain/candidate.dart';
import 'package:datingapp/profile/domain/profile.dart';
import 'package:datingapp/profile/domain/prompt.dart';

/// A [DiscoveryCandidate] with sensible defaults, for widget tests.
DiscoveryCandidate fakeCandidate({
  int id = 1,
  String name = 'Priya',
  int age = 26,
  int? distanceKm = 3,
  String? bio,
  String? goal,
  bool verified = false,
  List<String> interests = const [],
  List<String> shared = const [],
  List<AnsweredPrompt> prompts = const [],
  int photos = 0,
}) => DiscoveryCandidate(
  id: id,
  displayName: name,
  age: age,
  bio: bio,
  relationshipGoal: goal,
  isVerified: verified,
  distanceKm: distanceKm,
  sharedInterestsCount: shared.length,
  sharedInterests: shared,
  interests: interests,
  prompts: prompts,
  photos: [
    for (var i = 0; i < photos; i++)
      ProfilePhoto(
        id: i,
        url: 'https://photos.test/$id-$i.jpg',
        sortOrder: i,
        moderationStatus: 'approved',
      ),
  ],
);
