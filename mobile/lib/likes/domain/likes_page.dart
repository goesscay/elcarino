import '../../discovery/domain/candidate.dart';

/// One page of either Likes list (`GET /likes/received` or `/likes/sent`,
/// docs/03 "Likes").
///
/// [locked] is only ever true for "who liked me" and a non-subscriber: the
/// server then sends the [total] and *no people at all*, so there's nothing on
/// the device to reveal — the paywall is not a blur over real photos.
class LikesPage {
  const LikesPage({
    required this.likes,
    required this.total,
    required this.hasMore,
    this.locked = false,
  });

  factory LikesPage.fromJson(Map<String, dynamic> json) => LikesPage(
    likes: (json['likes'] as List<dynamic>)
        .map((e) => DiscoveryCandidate.fromJson(e as Map<String, dynamic>))
        .toList(),
    total: json['total'] as int,
    hasMore: (json['meta'] as Map<String, dynamic>)['has_more'] as bool,
    locked: json['locked'] as bool? ?? false,
  );

  final List<DiscoveryCandidate> likes;
  final int total;
  final bool hasMore;
  final bool locked;
}
