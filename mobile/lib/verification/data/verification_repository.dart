import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../domain/verification.dart';

/// Calls `/api/v1/verification/*` (docs/03 "Verification"). Failures come back
/// as `ApiException`s with the codes the screen reacts to: `challenge_expired`,
/// `verification_in_progress`, `too_many_attempts`, `photo_required`,
/// `already_verified`, `invalid_image`.
class VerificationRepository {
  VerificationRepository(this._client);

  final ApiClient _client;

  Future<VerificationState> getStatus() async {
    final response = await _client.request(
      '/verification/status',
      method: 'GET',
    );
    return VerificationState.fromJson(response.data as Map<String, dynamic>);
  }

  Future<VerificationChallenge> getChallenge() async {
    final response = await _client.request(
      '/verification/challenge',
      method: 'GET',
    );
    return VerificationChallenge.fromJson(
      response.data['challenge'] as Map<String, dynamic>,
    );
  }

  /// Uploads the selfie with the pose it was taken for. The server decides
  /// synchronously (a confident match is approved on the spot, everything else
  /// waits for a person), so the returned request is already the answer.
  Future<VerificationRequestInfo> submit({
    required String selfiePath,
    required String pose,
  }) async {
    final form = FormData.fromMap({
      'pose': pose,
      'selfie': await MultipartFile.fromFile(selfiePath),
    });
    final response = await _client.request(
      '/verification/request',
      method: 'POST',
      data: form,
    );
    return VerificationRequestInfo.fromJson(
      response.data['request'] as Map<String, dynamic>,
    );
  }
}

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => VerificationRepository(ref.watch(apiClientProvider)),
);
