import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../domain/explore_interest.dart';

/// Calls `/api/v1/explore/*` (docs/03 "Explore"). Both reads throw
/// `ApiException` with `location_required` / `preferences_required` when the
/// viewer hasn't set those yet, exactly like the discovery feed.
class ExploreRepository {
  ExploreRepository(this._client);

  final ApiClient _client;

  Future<List<ExploreInterest>> getInterests() async {
    final response = await _client.request('/explore/interests', method: 'GET');
    return (response.data['interests'] as List<dynamic>)
        .map((e) => ExploreInterest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExplorePeoplePage> getPeople(
    int interestId, {
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.request(
      '/explore/interests/$interestId/people',
      method: 'GET',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    return ExplorePeoplePage.fromJson(response.data as Map<String, dynamic>);
  }
}

final exploreRepositoryProvider = Provider<ExploreRepository>(
  (ref) => ExploreRepository(ref.watch(apiClientProvider)),
);
