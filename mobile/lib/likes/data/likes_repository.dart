import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../domain/likes_page.dart';

/// Calls `/api/v1/likes/{received,sent}` (docs/03 "Likes").
class LikesRepository {
  LikesRepository(this._client);

  final ApiClient _client;

  /// Who liked me. For a non-subscriber the page comes back `locked` with a
  /// count and no people.
  Future<LikesPage> getReceived({int page = 1, int perPage = 20}) =>
      _get('/likes/received', page, perPage);

  /// People I liked who haven't matched with me. Free.
  Future<LikesPage> getSent({int page = 1, int perPage = 20}) =>
      _get('/likes/sent', page, perPage);

  Future<LikesPage> _get(String path, int page, int perPage) async {
    final response = await _client.request(
      path,
      method: 'GET',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    return LikesPage.fromJson(response.data as Map<String, dynamic>);
  }
}

final likesRepositoryProvider = Provider<LikesRepository>(
  (ref) => LikesRepository(ref.watch(apiClientProvider)),
);
