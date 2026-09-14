<?php

namespace App\Services\Payments;

/**
 * Native store billing (open decision #27/#28's stated default) — a
 * *separate* code path from PaymentGateway, since the mobile client already
 * knows which store it purchased through and sends that store's own
 * receipt/token, not a generic "provider" request the server picks a
 * gateway for.
 */
interface ReceiptVerifier
{
    /**
     * @throws ReceiptVerificationException
     */
    public function verify(string $receipt): VerifiedReceipt;
}
