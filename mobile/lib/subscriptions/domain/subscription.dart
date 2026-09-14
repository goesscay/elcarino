import 'subscription_plan.dart';

/// docs/03-api-specification.md "Subscriptions": `GET /subscriptions/me`,
/// `POST /subscriptions`, `POST /subscriptions/cancel`.
class Subscription {
  const Subscription({
    required this.id,
    required this.status,
    required this.provider,
    required this.startedAt,
    required this.endsAt,
    required this.plan,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as int,
      status: json['status'] as String,
      provider: json['provider'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      plan: SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>),
    );
  }

  final int id;
  final String status;
  final String provider;
  final DateTime startedAt;
  final DateTime endsAt;
  final SubscriptionPlan plan;

  bool get isActive => status == 'active' && endsAt.isAfter(DateTime.now());
}
