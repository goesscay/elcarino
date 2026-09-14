/// Mirrors `App\Enums\CallType` on the backend.
enum CallType {
  voice('voice'),
  video('video');

  const CallType(this.apiValue);

  final String apiValue;

  factory CallType.fromApiValue(String value) =>
      CallType.values.firstWhere((t) => t.apiValue == value);
}
