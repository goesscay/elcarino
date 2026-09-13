import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../domain/candidate.dart';

class DiscoveryFeedPage {
  const DiscoveryFeedPage({required this.candidates, required this.hasMore});

  final List<DiscoveryCandidate> candidates;
  final bool hasMore;
}

/// Calls `/api/v1/{users/me/location,discovery/feed}` (docs/03-api-specification.md).
class DiscoveryRepository {
  DiscoveryRepository(this._client);

  final ApiClient _client;

  /// docs/06-security-architecture.md §4: "the client sends coarse
  /// coordinates (<= 3 decimal places, ~100 m) — the app does not upload GPS
  /// fixes." Truncated here, client-side, in addition to the server's own
  /// rounding — belt and suspenders on a stated privacy invariant, never
  /// relying on just one side enforcing it.
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _client.request(
      '/users/me/location',
      method: 'PUT',
      data: {
        'latitude': double.parse(latitude.toStringAsFixed(3)),
        'longitude': double.parse(longitude.toStringAsFixed(3)),
      },
    );
  }

  Future<DiscoveryFeedPage> getFeed({int page = 1, int perPage = 20}) async {
    final response = await _client.request(
      '/discovery/feed',
      method: 'GET',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final data = response.data as Map<String, dynamic>;
    final meta = data['meta'] as Map<String, dynamic>;

    return DiscoveryFeedPage(
      candidates: (data['candidates'] as List<dynamic>)
          .map((e) => DiscoveryCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: meta['has_more'] as bool,
    );
  }
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(ref.watch(apiClientProvider)),
);
