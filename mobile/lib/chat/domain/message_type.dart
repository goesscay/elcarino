/// Mirrors `App\Enums\MessageType` on the backend. Only [text] is ever sent
/// by this feature — voiceNote/gif/photo are open decisions #16-18,
/// unconfirmed [TBD-16/17/18] — but the full enum is declared now so an
/// unrecognised value from a future server (or another client) never crashes
/// [MessageType.fromApiValue], and no migration is needed if/when the rest
/// are confirmed in scope.
enum MessageType {
  text('text'),
  voiceNote('voice_note'),
  gif('gif'),
  photo('photo');

  const MessageType(this.apiValue);

  final String apiValue;

  factory MessageType.fromApiValue(String value) => MessageType.values
      .firstWhere((t) => t.apiValue == value, orElse: () => MessageType.text);
}
