<?php

namespace App\Services\Payments;

use App\Models\SubscriptionPlan;
use App\Models\User;

/**
 * Backs the client-facing `provider: "stripe"` purchase path (open decision
 * #27) — bound via `services.payments.provider`, same provider-agnostic-
 * interface-with-a-safe-local-default pattern as SmsSender/PushSender.
 * Native store billing (`app_store`/`play_store`) is a *separate* code path
 * (ReceiptVerifier) — the mobile app already knows which store it's running
 * under, so there's nothing to switch on server-side for those two.
 */
interface PaymentGateway
{
    public function startCheckout(User $user, SubscriptionPlan $plan): CheckoutResult;

    /**
     * @param  string  $providerSubscriptionId  as stored on the Subscription row
     */
    public function cancel(string $providerSubscriptionId): void;
}
