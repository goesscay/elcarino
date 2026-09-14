<?php

namespace App\Services\Subscriptions;

use App\Models\Subscription;

/**
 * Exactly one of the two is set: a Stripe purchase that redirected returns
 * only `checkoutUrl` (the Subscription doesn't exist yet — the webhook
 * creates it once Stripe confirms payment); every other successful path
 * (LogPaymentGateway, a verified native-store receipt) returns the
 * `subscription` it created immediately.
 */
final class PurchaseOutcome
{
    public function __construct(
        public readonly ?Subscription $subscription,
        public readonly ?string $checkoutUrl,
    ) {}
}
