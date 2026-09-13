import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../domain/match.dart';
import '../domain/swipe_direction.dart';

class SwipeResult {
  const SwipeResult({required this.matched, required this.matchId});

  final bool matched;
  final int? matchId;
}

/// Calls `/api/v1/{swipes,matches}` (docs/03-api-specification.md).
class MatchingRepository {
  MatchingRepository(this._client);

  final ApiClient _client;

  Future<SwipeResult> swipe({required int targetId, required SwipeDirection direction}) async {
    final response = await _client.request(
      '/swipes',
      method: 'POST',
      data: {'target_id': targetId, 'direction': direction.apiValue},
    );
    return SwipeResult(
      matched: response.data['matched'] as bool,
      matchId: response.data['match_id'] as int?,
    );
  }

  Future<List<UserMatch>> getMatches() async {
    final response = await _client.request('/matches', method: 'GET');
    return (response.data['matches'] as List<dynamic>)
        .map((e) => UserMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> unmatch(int matchId) async {
    await _client.request('/matches/$matchId', method: 'DELETE');
  }
}

final matchingRepositoryProvider = Provider<MatchingRepository>(
  (ref) => MatchingRepository(ref.watch(apiClientProvider)),
);
