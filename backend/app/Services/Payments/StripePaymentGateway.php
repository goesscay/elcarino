<?php

namespace App\Services\Payments;

use App\Enums\BillingInterval;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Real gateway (open decision #27 — chosen as this feature's working
 * default over native store billing, see docs/04-development-phases.md
 * item 1). Calls Stripe's classic form-encoded REST API directly via the
 * `Http` facade rather than pulling in `stripe/stripe-php` — same choice
 * TwilioSmsSender/FcmPushSender already made for their providers, and it
 * keeps this testable with `Http::fake()` the same way the rest of this
 * suite tests outbound HTTP.
 *
 * Not verified against a real Stripe account on this machine (none
 * configured) — same status as `TwilioSmsSender`/`FcmPushSender`: confirm
 * before relying on this in production.
 */
class StripePaymentGateway implements PaymentGateway
{
    private const API_BASE = 'https://api.stripe.com/v1';

    public function __construct(
        private readonly ?string $secretKey = null,
        private readonly ?string $successUrl = null,
        private readonly ?string $cancelUrl = null,
    ) {}

    public function startCheckout(User $user, SubscriptionPlan $plan): CheckoutResult
    {
        $this->assertConfigured();

        [$interval, $intervalCount] = $this->stripeInterval($plan->billing_interval);

        $response = $this->client()->asForm()->post(self::API_BASE.'/checkout/sessions', [
            'mode' => 'subscription',
            // Placeholder redirect targets — nothing in this feature builds
            // a mobile deep-link handler for a Stripe redirect yet (mobile
            // only drives the LogPaymentGateway path, see docs/04 item 1).
            // Flagged, not silently assumed correct.
            'success_url' => $this->successUrl ?? (config('app.url').'/subscriptions/checkout/success'),
            'cancel_url' => $this->cancelUrl ?? (config('app.url').'/subscriptions/checkout/cancel'),
            'customer_email' => $user->email,
            'client_reference_id' => (string) $user->id,
            'line_items' => [[
                'quantity' => 1,
                'price_data' => [
                    'currency' => strtolower($plan->currency),
                    'unit_amount' => $plan->price_cents,
                    'recurring' => [
                        'interval' => $interval,
                        'interval_count' => $intervalCount,
                    ],
                    'product_data' => [
                        'name' => $plan->name,
                    ],
                ],
            ]],
            'metadata' => [
                'user_id' => (string) $user->id,
                'plan_id' => (string) $plan->id,
            ],
        ]);

        if ($response->failed()) {
            throw new RuntimeException('Stripe checkout session creation failed: '.$response->body());
        }

        return CheckoutResult::pendingRedirect($response->json('url'));
    }

    public function cancel(string $providerSubscriptionId): void
    {
        $this->assertConfigured();

        $response = $this->client()->asForm()
            ->delete(self::API_BASE.'/subscriptions/'.$providerSubscriptionId);

        if ($response->failed()) {
            throw new RuntimeException('Stripe subscription cancellation failed: '.$response->body());
        }
    }

    private function client(): PendingRequest
    {
        return Http::withBasicAuth($this->secretKey, '');
    }

    private function assertConfigured(): void
    {
        if (! $this->secretKey) {
            throw new RuntimeException(
                'STRIPE_SECRET_KEY is not configured. Set it in .env, or switch PAYMENT_PROVIDER=log for local development.'
            );
        }
    }

    /**
     * Stripe's recurring price has no native "quarterly" interval — it's
     * `interval: month, interval_count: 3` instead.
     *
     * @return array{0: string, 1: int}
     */
    private function stripeInterval(BillingInterval $interval): array
    {
        return match ($interval) {
            BillingInterval::Monthly => ['month', 1],
            BillingInterval::Quarterly => ['month', 3],
            BillingInterval::Annual => ['year', 1],
        };
    }
}
