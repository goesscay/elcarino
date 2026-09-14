import 'dart:convert';

import 'package:datingapp/core/network/api_client.dart';
import 'package:datingapp/subscriptions/data/subscription_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_token_storage.dart';

class _FakeResponse {
  const _FakeResponse(this.body, {this.statusCode = 200});

  final Map<String, dynamic> body;
  final int statusCode;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, _FakeResponse> responses;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final response =
        responses[options.path] ?? const _FakeResponse({'message': 'ok'});
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

(SubscriptionRepository, _FakeAdapter) _repositoryReturning(
  Map<String, _FakeResponse> responses,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  final adapter = _FakeAdapter(responses);
  dio.httpClientAdapter = adapter;
  return (
    SubscriptionRepository(
      ApiClient(tokenStorage: FakeTokenStorage(), dio: dio),
    ),
    adapter,
  );
}

final _planJson = {
  'id': 1,
  'name': 'Premium',
  'price_cents': 999,
  'currency': 'USD',
  'billing_interval': 'monthly',
  'entitlements': {'unlimited_likes': true, 'boosts_per_month': 1},
};

final _subscriptionJson = {
  'id': 5,
  'status': 'active',
  'provider': 'stripe',
  'started_at': DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String(),
  // A future date, not a hardcoded literal — this fixture must stay "active"
  // (Subscription.isActive checks ends_at against the real clock) no matter
  // when the suite actually runs.
  'ends_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
  'plan': _planJson,
};

void main() {
  group('SubscriptionRepository (docs/03 Subscriptions)', () {
    test('getPlans maps every plan, entitlements included', () async {
      final (repository, _) = _repositoryReturning({
        '/subscriptions/plans': _FakeResponse({
          'plans': [_planJson],
        }),
      });

      final plans = await repository.getPlans();

      expect(plans, hasLength(1));
      expect(plans.first.name, 'Premium');
      expect(plans.first.formattedPrice, 'USD 9.99');
      expect(plans.first.entitlementBool('unlimited_likes'), isTrue);
    });

    test('getCurrent returns null when there is no subscription', () async {
      final (repository, _) = _repositoryReturning({
        '/subscriptions/me': _FakeResponse({
          'subscription': null,
          'entitlements': {},
        }),
      });

      expect(await repository.getCurrent(), isNull);
    });

    test('getCurrent parses an active subscription', () async {
      final (repository, _) = _repositoryReturning({
        '/subscriptions/me': _FakeResponse({
          'subscription': _subscriptionJson,
          'entitlements': _planJson['entitlements'],
        }),
      });

      final subscription = await repository.getCurrent();

      expect(subscription, isNotNull);
      expect(subscription!.status, 'active');
      expect(subscription.plan.name, 'Premium');
      expect(subscription.isActive, isTrue);
    });

    test('purchase always sends provider stripe', () async {
      final (repository, adapter) = _repositoryReturning({
        '/subscriptions': _FakeResponse({
          'subscription': _subscriptionJson,
        }, statusCode: 201),
      });

      await repository.purchase(1);

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.data, {'plan_id': 1, 'provider': 'stripe'});
    });

    test(
      'purchase returns an active subscription on the log-gateway/native path',
      () async {
        final (repository, _) = _repositoryReturning({
          '/subscriptions': _FakeResponse({
            'subscription': _subscriptionJson,
          }, statusCode: 201),
        });

        final result = await repository.purchase(1);

        expect(result.isActiveImmediately, isTrue);
        expect(result.subscription!.plan.name, 'Premium');
        expect(result.checkoutUrl, isNull);
      },
    );

    test(
      'purchase returns a checkout url on the Stripe-redirect path',
      () async {
        final (repository, _) = _repositoryReturning({
          '/subscriptions': _FakeResponse({
            'checkout_url': 'https://checkout.stripe.com/c/pay/cs_test_abc',
          }, statusCode: 202),
        });

        final result = await repository.purchase(1);

        expect(result.isActiveImmediately, isFalse);
        expect(result.subscription, isNull);
        expect(
          result.checkoutUrl,
          'https://checkout.stripe.com/c/pay/cs_test_abc',
        );
      },
    );

    test(
      'cancel posts to /subscriptions/cancel and parses the result',
      () async {
        final (repository, adapter) = _repositoryReturning({
          '/subscriptions/cancel': _FakeResponse({
            'subscription': {..._subscriptionJson, 'status': 'canceled'},
          }),
        });

        final subscription = await repository.cancel();

        expect(adapter.lastRequest!.method, 'POST');
        expect(adapter.lastRequest!.path, '/subscriptions/cancel');
        expect(subscription.status, 'canceled');
        expect(subscription.isActive, isFalse);
      },
    );
  });
}
