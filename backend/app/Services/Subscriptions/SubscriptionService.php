<?php

namespace App\Services\Subscriptions;

use App\Enums\BillingInterval;
use App\Enums\PaymentStatus;
use App\Enums\SubscriptionProvider;
use App\Enums\SubscriptionStatus;
use App\Models\Payment;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Payments\AppStoreReceiptVerifier;
use App\Services\Payments\PaymentGateway;
use App\Services\Payments\PlayStoreReceiptVerifier;
use App\Services\Payments\ReceiptVerifier;
use App\Services\Payments\VerifiedReceipt;
use Illuminate\Support\Carbon;
use InvalidArgumentException;
use RuntimeException;

/**
 * Phase 2 item 1's orchestrator. Two independent ways in — `$gateway`
 * (provider-agnostic, backs `provider: "stripe"`, log-driven locally) and
 * the two native-store `ReceiptVerifier`s (`provider: "app_store"` /
 * `"play_store"`, real-shaped but unconfigured — see their own doc
 * comments) — both funnel through the same `activate()` so a Subscription
 * row is created exactly one way regardless of how payment was actually
 * collected.
 */
class SubscriptionService
{
    public function __construct(
        private readonly PaymentGateway $gateway,
        private readonly AppStoreReceiptVerifier $appStoreVerifier,
        private readonly PlayStoreReceiptVerifier $playStoreVerifier,
    ) {}

    public function purchase(User $user, SubscriptionPlan $plan, SubscriptionProvider $provider, ?string $receipt): PurchaseOutcome
    {
        return match ($provider) {
            SubscriptionProvider::Stripe => $this->purchaseViaGateway($user, $plan),
            SubscriptionProvider::AppStore => $this->purchaseViaReceipt($user, $plan, $provider, $this->appStoreVerifier, $receipt),
            SubscriptionProvider::PlayStore => $this->purchaseViaReceipt($user, $plan, $provider, $this->playStoreVerifier, $receipt),
            SubscriptionProvider::Other => throw new InvalidArgumentException('No verifier/gateway exists for provider "other".'),
        };
    }

    /**
     * docs/06-security-architecture.md §9-adjacent: cancelling stops
     * granting access immediately (status -> canceled, ends_at -> now) —
     * this MVP doesn't implement "keep access until the paid period ends,"
     * which real billing UX usually wants; flagged, not silently the
     * friendlier behaviour by accident.
     */
    public function cancel(User $user, Subscription $subscription): Subscription
    {
        if ($subscription->provider === SubscriptionProvider::Stripe
            && $subscription->provider_subscription_id
            && ! str_starts_with($subscription->provider_subscription_id, 'log-')) {
            $this->gateway->cancel($subscription->provider_subscription_id);
        }

        $subscription->forceFill([
            'status' => SubscriptionStatus::Canceled,
            'ends_at' => now(),
        ])->save();

        return $subscription;
    }

    /**
     * Called by StripeWebhookController after signature verification
     * (StripeWebhookSignatureVerifier) — this method trusts its input
     * completely, so nothing before this call site may skip that check.
     * Handles the three events that matter for this feature's scope:
     * activation, cancellation, and a failed renewal charge. Deliberately
     * NOT handled: `invoice.payment_succeeded` extending `ends_at` on
     * renewal — every subscription this feature creates gets exactly one
     * billing period and then lapses even if Stripe keeps charging the
     * customer successfully. Flagged as the natural next fast-follow, not
     * silently dropped.
     *
     * @param  array<string, mixed>  $event  decoded Stripe Event object
     */
    public function handleStripeEvent(array $event): void
    {
        $object = $event['data']['object'] ?? [];

        match ($event['type'] ?? null) {
            'checkout.session.completed' => $this->handleCheckoutCompleted($object),
            'customer.subscription.deleted' => $this->handleSubscriptionDeleted($object),
            'invoice.payment_failed' => $this->handlePaymentFailed($object),
            default => null, // Every other event type is intentionally ignored.
        };
    }

    private function purchaseViaGateway(User $user, SubscriptionPlan $plan): PurchaseOutcome
    {
        $result = $this->gateway->startCheckout($user, $plan);

        if (! $result->isActiveImmediately) {
            return new PurchaseOutcome(subscription: null, checkoutUrl: $result->checkoutUrl);
        }

        $subscription = $this->activate(
            $user,
            $plan,
            SubscriptionProvider::Stripe,
            $result->providerSubscriptionId,
            now(),
            $this->periodEnd($plan->billing_interval),
        );

        return new PurchaseOutcome(subscription: $subscription, checkoutUrl: null);
    }

    private function purchaseViaReceipt(User $user, SubscriptionPlan $plan, SubscriptionProvider $provider, ReceiptVerifier $verifier, ?string $receipt): PurchaseOutcome
    {
        if (! $receipt) {
            throw new InvalidArgumentException("A receipt is required for provider \"{$provider->value}\".");
        }

        /** @var VerifiedReceipt $verified */
        $verified = $verifier->verify($receipt);

        $subscription = $this->activate(
            $user,
            $plan,
            $provider,
            $verified->providerSubscriptionId,
            now(),
            $verified->expiresAt,
        );

        return new PurchaseOutcome(subscription: $subscription, checkoutUrl: null);
    }

    private function handleCheckoutCompleted(array $session): void
    {
        $userId = $session['metadata']['user_id'] ?? null;
        $planId = $session['metadata']['plan_id'] ?? null;
        $stripeSubscriptionId = $session['subscription'] ?? null;

        if (! $userId || ! $planId || ! $stripeSubscriptionId) {
            throw new RuntimeException('checkout.session.completed event missing metadata.user_id/plan_id or subscription id.');
        }

        $user = User::query()->findOrFail($userId);
        $plan = SubscriptionPlan::query()->findOrFail($planId);

        $this->activate($user, $plan, SubscriptionProvider::Stripe, $stripeSubscriptionId, now(), $this->periodEnd($plan->billing_interval));
    }

    private function handleSubscriptionDeleted(array $stripeSubscription): void
    {
        $id = $stripeSubscription['id'] ?? null;
        if (! $id) {
            return;
        }

        Subscription::query()
            ->where('provider_subscription_id', $id)
            ->update(['status' => SubscriptionStatus::Canceled, 'ends_at' => now()]);
    }

    private function handlePaymentFailed(array $invoice): void
    {
        $id = $invoice['subscription'] ?? null;
        if (! $id) {
            return;
        }

        Subscription::query()
            ->where('provider_subscription_id', $id)
            ->update(['status' => SubscriptionStatus::PastDue]);
    }

    /**
     * Idempotent on `provider_subscription_id` — a retried Stripe webhook
     * delivery (or a client retrying a synchronous purchase call) must not
     * create a second Subscription/Payment pair for the same external
     * charge.
     */
    private function activate(
        User $user,
        SubscriptionPlan $plan,
        SubscriptionProvider $provider,
        string $providerSubscriptionId,
        Carbon $startedAt,
        Carbon $endsAt,
    ): Subscription {
        $subscription = Subscription::query()->updateOrCreate(
            ['provider_subscription_id' => $providerSubscriptionId],
            [
                'user_id' => $user->id,
                'plan_id' => $plan->id,
                'status' => SubscriptionStatus::Active,
                'started_at' => $startedAt,
                'ends_at' => $endsAt,
                'provider' => $provider,
            ],
        );

        Payment::query()->firstOrCreate(
            ['provider_reference' => $providerSubscriptionId],
            [
                'user_id' => $user->id,
                'subscription_id' => $subscription->id,
                'amount_cents' => $plan->price_cents,
                'currency' => $plan->currency,
                'status' => PaymentStatus::Succeeded,
            ],
        );

        return $subscription->fresh('plan');
    }

    private function periodEnd(BillingInterval $interval): Carbon
    {
        return match ($interval) {
            BillingInterval::Monthly => now()->addMonth(),
            BillingInterval::Quarterly => now()->addMonths(3),
            BillingInterval::Annual => now()->addYear(),
        };
    }
}
