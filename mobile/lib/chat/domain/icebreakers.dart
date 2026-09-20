/// A few tappable opening lines for a new conversation
/// (`GET /chat/conversations/{id}/icebreakers`, docs/03 "Chat" — Phase 4,
/// open decision #25).
class IcebreakerSet {
  const IcebreakerSet({required this.lines, required this.source});

  factory IcebreakerSet.fromJson(Map<String, dynamic> json) => IcebreakerSet(
    lines: List<String>.from(json['icebreakers'] as List<dynamic>),
    source: json['source'] as String,
  );

  final List<String> lines;

  /// `template` (built from fixed patterns) or `ai` (written by a model).
  final String source;

  /// AI-written lines are labelled as such: people should know when a machine
  /// wrote something they're about to send as their own.
  bool get isAi => source == 'ai';
}
