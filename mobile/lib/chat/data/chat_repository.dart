import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';

class MessagePage {
  const MessagePage({required this.messages, required this.hasMore});

  final List<Message> messages;
  final bool hasMore;
}

/// Calls `/api/v1/chat` (docs/03-api-specification.md "Chat"). Real-time
/// delivery/presence/typing go through [ChatSocketService] instead — this is
/// REST only: initial load, history, sending, and marking read.
class ChatRepository {
  ChatRepository(this._client);

  final ApiClient _client;

  Future<List<Conversation>> getConversations() async {
    final response = await _client.request(
      '/chat/conversations',
      method: 'GET',
    );
    return (response.data['conversations'] as List<dynamic>)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Newest-first, per the backend's pagination order — callers building a
  /// reverse-chronological message list can append pages directly.
  Future<MessagePage> getMessages(int conversationId, {int page = 1}) async {
    final response = await _client.request(
      '/chat/conversations/$conversationId/messages',
      method: 'GET',
      queryParameters: {'page': page},
    );
    final messages = (response.data['messages'] as List<dynamic>)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
    return MessagePage(
      messages: messages,
      hasMore: response.data['meta']['has_more'] as bool,
    );
  }

  Future<Message> sendMessage(int conversationId, String body) async {
    final response = await _client.request(
      '/chat/conversations/$conversationId/messages',
      method: 'POST',
      data: {'body': body},
    );
    return Message.fromJson(response.data['message'] as Map<String, dynamic>);
  }

  /// Phase 3 item 1 (voice notes, open decision #16). Mirrors
  /// `ProfileRepository.uploadPhoto`'s `FormData`/`MultipartFile.fromFile`
  /// pattern — same reason: goes through the shared `request()` wrapper so a
  /// 422 (non-audio mime, oversized file, missing duration) surfaces as the
  /// same typed `ApiException`/`ValidationException` every other screen
  /// handles.
  Future<Message> sendVoiceNote(
    int conversationId,
    String filePath,
    int durationSeconds,
  ) async {
    final form = FormData.fromMap({
      'voice_note': await MultipartFile.fromFile(filePath),
      'duration_seconds': durationSeconds,
    });
    final response = await _client.request(
      '/chat/conversations/$conversationId/messages',
      method: 'POST',
      data: form,
    );
    return Message.fromJson(response.data['message'] as Map<String, dynamic>);
  }

  Future<void> markRead(int conversationId) async {
    await _client.request(
      '/chat/conversations/$conversationId/read',
      method: 'PUT',
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);
