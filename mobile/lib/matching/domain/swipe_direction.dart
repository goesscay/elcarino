/// Mirrors `App\Enums\SwipeDirection` on the backend. `super` is accepted by
/// the API (matches the schema enum) but Super Like's proposed extras
/// (limits, premium gating, a distinct match celebration, the swipe-up
/// gesture) aren't built — [TBD-11], pending open decision #11 — so the UI
/// only ever sends `left`/`right`.
enum SwipeDirection {
  left('left'),
  right('right'),
  superLike('super');

  const SwipeDirection(this.apiValue);

  final String apiValue;
}
