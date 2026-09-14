<?php

namespace Tests\Unit\Services\Payments;

use App\Enums\BillingInterval;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Payments\StripePaymentGateway;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Tests\TestCase;

/**
 * Not verified against a real Stripe account (none configured on this
 * machine) — this asserts the request this app *sends* is shaped the way
 * Stripe's documented Checkout Sessions API expects, and that a real-looking
 * response is parsed correctly. Same "confirm before production" status as
 * TwilioSmsSender/FcmPushSender's own tests would be, had they had any.
 */
class StripePaymentGatewayTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_a_checkout_session_and_returns_the_redirect_url(): void
    {
        Http::fake([
            'https://api.stripe.com/v1/checkout/sessions' => Http::response([
                'id' => 'cs_test_123',
                'url' => 'https://checkout.stripe.com/c/pay/cs_test_123',
            ]),
        ]);

        $user = User::factory()->create(['email' => 'jane@example.com']);
        $plan = SubscriptionPlan::factory()->create([
            'name' => 'Premium',
            'price_cents' => 999,
            'currency' => 'USD',
            'billing_interval' => BillingInterval::Quarterly,
        ]);

        $gateway = new StripePaymentGateway('sk_test_123', 'https://app.example.com/success', 'https://app.example.com/cancel');
        $result = $gateway->startCheckout($user, $plan);

        $this->assertFalse($result->isActiveImmediately);
        $this->assertSame('https://checkout.stripe.com/c/pay/cs_test_123', $result->checkoutUrl);

        Http::assertSent(function ($request) use ($user, $plan) {
            return $request->url() === 'https://api.stripe.com/v1/checkout/sessions'
                && $request['mode'] === 'subscription'
                && $request['client_reference_id'] === (string) $user->id
                && $request['metadata']['plan_id'] === (string) $plan->id
                && $request['line_items'][0]['price_data']['unit_amount'] === $plan->price_cents
                // Quarterly has no native Stripe interval — month x3.
                && $request['line_items'][0]['price_data']['recurring']['interval'] === 'month'
                && $request['line_items'][0]['price_data']['recurring']['interval_count'] === 3;
        });
    }

    public function test_it_refuses_to_call_stripe_when_unconfigured(): void
    {
        $user = User::factory()->create();
        $plan = SubscriptionPlan::factory()->create();

        $this->expectException(RuntimeException::class);
        (new StripePaymentGateway)->startCheckout($user, $plan);
    }

    public function test_a_failed_response_throws(): void
    {
        Http::fake(['https://api.stripe.com/*' => Http::response(['error' => 'bad request'], 400)]);

        $user = User::factory()->create();
        $plan = SubscriptionPlan::factory()->create();

        $this->expectException(RuntimeException::class);
        (new StripePaymentGateway('sk_test_123'))->startCheckout($user, $plan);
    }

    public function test_cancel_calls_the_subscription_delete_endpoint(): void
    {
        Http::fake(['https://api.stripe.com/v1/subscriptions/*' => Http::response(['id' => 'sub_123', 'status' => 'canceled'])]);

        (new StripePaymentGateway('sk_test_123'))->cancel('sub_123');

        Http::assertSent(fn ($request) => $request->url() === 'https://api.stripe.com/v1/subscriptions/sub_123'
            && $request->method() === 'DELETE');
    }
}
