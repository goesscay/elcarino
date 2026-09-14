<?php

namespace App\Services\Payments;

/**
 * Verifies Stripe's `Stripe-Signature` header without pulling in
 * `stripe/stripe-php` just for this — the scheme is simple and documented:
 * the header is `t=<unix timestamp>,v1=<hex hmac>`, and the expected
 * signature is `hash_hmac('sha256', "{timestamp}.{raw body}", webhookSecret)`.
 * A webhook is the one endpoint in this app with no Sanctum bearer token at
 * all (Stripe can't hold one) — this signature check is the entire
 * authentication for it, so it fails closed on anything malformed, not just
 * a mismatched signature.
 */
class StripeWebhookSignatureVerifier
{
    /**
     * @param  int  $tolerance  seconds — rejects a replayed old payload,
     *                          mirroring Stripe's own SDK default (5 minutes)
     */
    public function verify(string $payload, ?string $signatureHeader, string $webhookSecret, int $tolerance = 300): bool
    {
        if (! $signatureHeader) {
            return false;
        }

        $parts = [];
        foreach (explode(',', $signatureHeader) as $pair) {
            [$key, $value] = array_pad(explode('=', $pair, 2), 2, null);
            $parts[$key][] = $value;
        }

        $timestamp = $parts['t'][0] ?? null;
        $signatures = $parts['v1'] ?? [];

        if (! $timestamp || ! ctype_digit($timestamp) || empty($signatures)) {
            return false;
        }

        if (abs(time() - (int) $timestamp) > $tolerance) {
            return false;
        }

        $expected = hash_hmac('sha256', "{$timestamp}.{$payload}", $webhookSecret);

        foreach ($signatures as $signature) {
            if (is_string($signature) && hash_equals($expected, $signature)) {
                return true;
            }
        }

        return false;
    }
}
