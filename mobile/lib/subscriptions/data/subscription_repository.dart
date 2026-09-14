import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../domain/purchase_result.dart';
import '../domain/subscription.dart';
import '../domain/subscription_plan.dart';

/// Calls `/api/v1/subscriptions` (docs/03-api-specification.md
/// "Subscriptions"). Only the `provider: "stripe"` path is exercised from
/// mobile (Phase 2 item 1) — native store billing (`app_store`/
/// `play_store`) has real backend endpoints (docs/04) but no mobile UI yet,
/// same disclosed-gap pattern as the Google/Apple sign-in buttons in
/// onboarding (Phase 1 item 2).
class SubscriptionRepository {
  SubscriptionRepository(this._client);

  final ApiClient _client;

  Future<List<SubscriptionPlan>> getPlans() async {
    final response = await _client.request(
      '/subscriptions/plans',
      method: 'GET',
    );
    return (response.data['plans'] as List<dynamic>)
        .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns `null` if the caller has no active subscription.
  Future<Subscription?> getCurrent() async {
    final response = await _client.request('/subscriptions/me', method: 'GET');
    final data = response.data['subscription'];
    return data == null
        ? null
        : Subscription.fromJson(data as Map<String, dynamic>);
  }

  /// Always sends `provider: "stripe"` — see class doc. The backend decides
  /// whether that activates immediately (local dev's log-driven gateway) or
  /// returns a Stripe Checkout URL (a real, configured Stripe account);
  /// this repository doesn't need to know which, it just relays the result.
  Future<PurchaseResult> purchase(int planId) async {
    final response = await _client.request(
      '/subscriptions',
      method: 'POST',
      data: {'plan_id': planId, 'provider': 'stripe'},
    );

    final subscriptionJson = response.data['subscription'];
    if (subscriptionJson != null) {
      return PurchaseResult(
        subscription: Subscription.fromJson(
          subscriptionJson as Map<String, dynamic>,
        ),
      );
    }

    return PurchaseResult(
      checkoutUrl: response.data['checkout_url'] as String?,
    );
  }

  Future<Subscription> cancel() async {
    final response = await _client.request(
      '/subscriptions/cancel',
      method: 'POST',
    );
    return Subscription.fromJson(
      response.data['subscription'] as Map<String, dynamic>,
    );
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(ref.watch(apiClientProvider)),
);
