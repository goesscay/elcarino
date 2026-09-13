import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../domain/blocked_user.dart';
import '../domain/report_category.dart';

/// Calls `/api/v1/safety` (docs/03-api-specification.md "Safety"). Unmatch
/// itself lives in `matching/data/matching_repository.dart` (item 6, already
/// existed before this feature) — this is Block and Report only.
class SafetyRepository {
  SafetyRepository(this._client);

  final ApiClient _client;

  Future<List<BlockedUser>> getBlockedUsers() async {
    final response = await _client.request('/safety/blocks', method: 'GET');
    return (response.data['blocked_users'] as List<dynamic>)
        .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Idempotent on the backend — safe to call even if already blocked.
  Future<void> block(int userId) async {
    await _client.request(
      '/safety/block',
      method: 'POST',
      data: {'user_id': userId},
    );
  }

  /// Idempotent on the backend — safe to call even if not currently blocked.
  Future<void> unblock(int userId) async {
    await _client.request('/safety/block/$userId', method: 'DELETE');
  }

  Future<void> report({
    required int userId,
    required ReportCategory category,
    String? description,
    bool alsoBlock = false,
  }) async {
    await _client.request(
      '/safety/report',
      method: 'POST',
      data: {
        'user_id': userId,
        'category': category.apiValue,
        if (description != null && description.isNotEmpty)
          'description': description,
        'also_block': alsoBlock,
      },
    );
  }
}

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(ref.watch(apiClientProvider)),
);
