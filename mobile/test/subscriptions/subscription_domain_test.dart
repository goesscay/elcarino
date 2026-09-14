import 'package:datingapp/subscriptions/domain/subscription.dart';
import 'package:datingapp/subscriptions/domain/subscription_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionPlan', () {
    test('billingIntervalLabel maps the three known intervals', () {
      SubscriptionPlan plan(String interval) => SubscriptionPlan(
        id: 1,
        name: 'Plan',
        priceCents: 100,
        currency: 'USD',
        billingInterval: interval,
        entitlements: const {},
      );

      expect(plan('monthly').billingIntervalLabel, 'month');
      expect(plan('quarterly').billingIntervalLabel, 'quarter');
      expect(plan('annual').billingIntervalLabel, 'year');
    });

    test('entitlementBool is false for a missing or falsy key', () {
      final plan = SubscriptionPlan(
        id: 1,
        name: 'Plan',
        priceCents: 100,
        currency: 'USD',
        billingInterval: 'monthly',
        entitlements: const {'advanced_filters': false},
      );

      expect(plan.entitlementBool('advanced_filters'), isFalse);
      expect(plan.entitlementBool('nonexistent'), isFalse);
    });
  });

  group('Subscription', () {
    SubscriptionPlan plan() => const SubscriptionPlan(
      id: 1,
      name: 'Premium',
      priceCents: 999,
      currency: 'USD',
      billingInterval: 'monthly',
      entitlements: {},
    );

    test(
      'isActive is false once ends_at is in the past, even if status is active',
      () {
        final subscription = Subscription(
          id: 1,
          status: 'active',
          provider: 'stripe',
          startedAt: DateTime.now().subtract(const Duration(days: 40)),
          endsAt: DateTime.now().subtract(const Duration(days: 10)),
          plan: plan(),
        );

        expect(subscription.isActive, isFalse);
      },
    );

    test(
      'isActive is false when status is canceled even with a future ends_at',
      () {
        final subscription = Subscription(
          id: 1,
          status: 'canceled',
          provider: 'stripe',
          startedAt: DateTime.now(),
          endsAt: DateTime.now().add(const Duration(days: 10)),
          plan: plan(),
        );

        expect(subscription.isActive, isFalse);
      },
    );
  });
}
