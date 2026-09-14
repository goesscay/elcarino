/// docs/03-api-specification.md "Subscriptions": `GET /subscriptions/plans`.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.currency,
    required this.billingInterval,
    required this.entitlements,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as int,
      name: json['name'] as String,
      priceCents: json['price_cents'] as int,
      currency: json['currency'] as String,
      billingInterval: json['billing_interval'] as String,
      entitlements: Map<String, dynamic>.from(
        json['entitlements'] as Map? ?? {},
      ),
    );
  }

  final int id;
  final String name;
  final int priceCents;
  final String currency;
  final String billingInterval;
  final Map<String, dynamic> entitlements;

  /// Currency-agnostic on purpose — this app has no locale-aware currency
  /// formatting (no `intl` dependency yet), and hardcoding "$" would be
  /// wrong the moment a non-USD plan exists. "USD 9.99", not "$9.99".
  String get formattedPrice =>
      '$currency ${(priceCents / 100).toStringAsFixed(2)}';

  String get billingIntervalLabel => switch (billingInterval) {
    'monthly' => 'month',
    'quarterly' => 'quarter',
    'annual' => 'year',
    _ => billingInterval,
  };

  bool entitlementBool(String key) => entitlements[key] == true;
}
