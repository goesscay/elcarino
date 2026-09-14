<?php

namespace App\Services\Payments;

/**
 * What starting a checkout produced — either the gateway already collected
 * payment synchronously (LogPaymentGateway, for local dev/testing — see its
 * own doc comment), or it handed back a redirect the client must complete
 * before anything is confirmed (StripePaymentGateway's Checkout Session).
 * Never both: a subscription is only ever created from `activatedImmediately`
 * here, or later from a verified Stripe webhook event — never from a bare
 * "the client says checkout succeeded" claim.
 */
final class CheckoutResult
{
    private function __construct(
        public readonly bool $isActiveImmediately,
        public readonly ?string $checkoutUrl,
        public readonly ?string $providerSubscriptionId,
    ) {}

    public static function activatedImmediately(?string $providerSubscriptionId = null): self
    {
        return new self(true, null, $providerSubscriptionId);
    }

    public static function pendingRedirect(string $checkoutUrl): self
    {
        return new self(false, $checkoutUrl, null);
    }
}
