<?php

namespace App\Services\Payments;

use Illuminate\Support\Carbon;

/**
 * A native-store purchase confirmed server-side. Never constructed from
 * unverified client input — only ever returned by a ReceiptVerifier after
 * the store's own API has confirmed the receipt/token is genuine, same
 * "never trust a client claim" discipline as OAuthUserPayload.
 */
final class VerifiedReceipt
{
    public function __construct(
        public readonly string $providerSubscriptionId,
        public readonly Carbon $expiresAt,
    ) {}
}
