/// Mirrors `App\Enums\CallStatus` on the backend. `failed` is declared but
/// never written by the backend this pass (no client-reported ICE-failure
/// endpoint exists yet) — included anyway so an unrecognised value never
/// crashes parsing, same reasoning as `MessageType.fromApiValue`.
enum CallStatus {
  ringing('ringing'),
  active('active'),
  ended('ended'),
  missed('missed'),
  declined('declined'),
  failed('failed');

  const CallStatus(this.apiValue);

  final String apiValue;

  factory CallStatus.fromApiValue(String value) => CallStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => CallStatus.ended,
  );
}
