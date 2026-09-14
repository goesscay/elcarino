import 'subscription.dart';

/// Mirrors the backend's `PurchaseOutcome` (App\Services\Subscriptions) —
/// exactly one of the two is set. `subscription` means the purchase is
/// already active (the log-driver default, or a verified native-store
/// receipt); `checkoutUrl` means Stripe needs the user to complete payment
/// in a browser before anything is confirmed.
class PurchaseResult {
  const PurchaseResult({this.subscription, this.checkoutUrl});

  final Subscription? subscription;
  final String? checkoutUrl;

  bool get isActiveImmediately => subscription != null;
}
