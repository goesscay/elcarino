/// A library prompt (`GET /prompts`) — not yet answered by the current user.
class PromptLibraryItem {
  const PromptLibraryItem({
    required this.id,
    required this.prompt,
    required this.category,
  });

  factory PromptLibraryItem.fromJson(Map<String, dynamic> json) =>
      PromptLibraryItem(
        id: json['id'] as int,
        prompt: json['prompt'] as String,
        category: json['category'] as String?,
      );

  final int id;
  final String prompt;
  final String? category;
}

/// The current user's answer to one prompt (`GET/PUT /prompts/me`).
class AnsweredPrompt {
  const AnsweredPrompt({
    required this.promptId,
    required this.promptText,
    required this.answer,
  });

  factory AnsweredPrompt.fromJson(Map<String, dynamic> json) => AnsweredPrompt(
    promptId: json['prompt_id'] as int,
    promptText: json['prompt'] as String? ?? '',
    answer: json['answer'] as String,
  );

  final int promptId;
  final String promptText;
  final String answer;
}
