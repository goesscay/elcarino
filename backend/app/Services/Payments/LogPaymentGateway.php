<?php

namespace App\Services\Payments;

use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Default local-dev gateway (PAYMENT_PROVIDER=log in .env.example), same
 * role as LogSmsSender/LogPushSender: no real charge happens, so — unlike
 * those two, which just relay a message a human still has to act on — this
 * one activates the subscription immediately, letting the whole purchase ->
 * entitlement-gated-feature flow be exercised end to end locally without a
 * Stripe account.
 */
class LogPaymentGateway implements PaymentGateway
{
    public function startCheckout(User $user, SubscriptionPlan $plan): CheckoutResult
    {
        Log::channel(config('logging.default'))->info('Payment (log driver) — activating without a real charge', [
            'user_id' => $user->id,
            'plan_id' => $plan->id,
            'plan' => $plan->name,
        ]);

        return CheckoutResult::activatedImmediately('log-'.Str::uuid());
    }

    public function cancel(string $providerSubscriptionId): void
    {
        Log::channel(config('logging.default'))->info('Payment (log driver) — cancel (no-op)', [
            'provider_subscription_id' => $providerSubscriptionId,
        ]);
    }
}
