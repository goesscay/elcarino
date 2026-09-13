import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../domain/gender.dart';
import '../domain/interest.dart';
import '../domain/preferences.dart';
import '../domain/profile.dart';
import '../domain/prompt.dart';

/// Calls the `/api/v1/{profiles,prompts,preferences}/*` endpoints
/// (docs/03-api-specification.md). Every "not created yet" case is a 404 with
/// the documented error envelope — surfaced here as `null`, not an exception,
/// so callers (the onboarding gate, "resume where I left off") don't need to
/// catch for the expected/normal first-run case.
class ProfileRepository {
  ProfileRepository(this._client);

  final ApiClient _client;

  Future<Profile?> getProfile() async {
    try {
      final response = await _client.request('/profiles/me', method: 'GET');
      return Profile.fromJson(response.data['profile'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.code == 'profile_not_found') return null;
      rethrow;
    }
  }

  Future<Profile> updateProfileBasics({
    required String displayName,
    required DateTime birthDate,
    required Gender gender,
    String? bio,
    String? relationshipGoal,
  }) async {
    final response = await _client.request(
      '/profiles/me',
      method: 'PUT',
      data: {
        'display_name': displayName,
        'birth_date':
            '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        'gender': gender.apiValue,
        'bio': ?bio,
        'relationship_goal': ?relationshipGoal,
      },
    );
    return Profile.fromJson(response.data['profile'] as Map<String, dynamic>);
  }

  Future<ProfilePhoto> uploadPhoto(String filePath) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath),
    });
    // Goes through the same request() wrapper as every other call (not
    // `_client.raw` directly) so a 422 (invalid_image, photo_limit_reached,
    // or the image/mimes shape-validation failure) comes back as the same
    // typed ApiException/ValidationException every other screen handles —
    // dio's request() accepts FormData for `data` just like any other body.
    final response = await _client.request(
      '/profiles/me/photos',
      method: 'POST',
      data: form,
    );
    return ProfilePhoto.fromJson(
      response.data['photo'] as Map<String, dynamic>,
    );
  }

  Future<void> deletePhoto(int photoId) async {
    await _client.request('/profiles/me/photos/$photoId', method: 'DELETE');
  }

  Future<void> reorderPhotos(List<int> orderedIds) async {
    await _client.request(
      '/profiles/me/photos/order',
      method: 'PUT',
      data: {'photo_ids': orderedIds},
    );
  }

  Future<List<PromptLibraryItem>> getPromptLibrary() async {
    final response = await _client.request('/prompts', method: 'GET');
    return (response.data['prompts'] as List<dynamic>)
        .map((e) => PromptLibraryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AnsweredPrompt>> getMyPrompts() async {
    final response = await _client.request('/prompts/me', method: 'GET');
    return (response.data['prompts'] as List<dynamic>)
        .map((e) => AnsweredPrompt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Full replace, matching the backend's `PUT /prompts/me` contract. The
  /// list's order becomes `sort_order` server-side — this is also how
  /// reordering answered prompts persists (docs/04 item 4): resubmit the same
  /// answers in the new order.
  Future<List<AnsweredPrompt>> updatePrompts(
    List<(int promptId, String answer)> answers,
  ) async {
    final response = await _client.request(
      '/prompts/me',
      method: 'PUT',
      data: {
        'prompts': [
          for (final (promptId, answer) in answers)
            {'prompt_id': promptId, 'answer': answer},
        ],
      },
    );
    return (response.data['prompts'] as List<dynamic>)
        .map((e) => AnsweredPrompt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deletePromptAnswer(int promptId) async {
    await _client.request('/prompts/me/$promptId', method: 'DELETE');
  }

  Future<Preferences?> getPreferences() async {
    try {
      final response = await _client.request('/preferences/me', method: 'GET');
      return Preferences.fromJson(
        response.data['preferences'] as Map<String, dynamic>,
      );
    } on ApiException catch (e) {
      if (e.code == 'preferences_not_found') return null;
      rethrow;
    }
  }

  Future<Preferences> updatePreferences(Preferences preferences) async {
    final response = await _client.request(
      '/preferences/me',
      method: 'PUT',
      data: preferences.toJson(),
    );
    return Preferences.fromJson(
      response.data['preferences'] as Map<String, dynamic>,
    );
  }

  Future<List<Interest>> getInterestCatalogue() async {
    final response = await _client.request('/interests', method: 'GET');
    return (response.data['interests'] as List<dynamic>)
        .map((e) => Interest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Interest>> getMyInterests() async {
    final response = await _client.request('/interests/me', method: 'GET');
    return (response.data['interests'] as List<dynamic>)
        .map((e) => Interest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Full replace, matching the backend's `PUT /interests/me` contract
  /// (`sync()` under the hood — a plain many-to-many, no pivot data).
  Future<List<Interest>> updateInterests(List<int> interestIds) async {
    final response = await _client.request(
      '/interests/me',
      method: 'PUT',
      data: {'interest_ids': interestIds},
    );
    return (response.data['interests'] as List<dynamic>)
        .map((e) => Interest.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);
