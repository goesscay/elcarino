<?php

namespace Tests\Unit\Services\Payments;

use App\Services\Payments\StripeWebhookSignatureVerifier;
use PHPUnit\Framework\TestCase;

/**
 * This is the entire authentication for the Stripe webhook endpoint
 * (StripeWebhookController) — no Sanctum token is possible there, so every
 * edge case here matters as much as any auth-middleware test elsewhere.
 */
class StripeWebhookSignatureVerifierTest extends TestCase
{
    private const SECRET = 'whsec_test_secret';

    private function sign(string $payload, int $timestamp, string $secret = self::SECRET): string
    {
        $signature = hash_hmac('sha256', "{$timestamp}.{$payload}", $secret);

        return "t={$timestamp},v1={$signature}";
    }

    public function test_a_correctly_signed_payload_verifies(): void
    {
        $payload = '{"type":"checkout.session.completed"}';
        $header = $this->sign($payload, time());

        $this->assertTrue((new StripeWebhookSignatureVerifier)->verify($payload, $header, self::SECRET));
    }

    public function test_a_missing_header_fails(): void
    {
        $this->assertFalse((new StripeWebhookSignatureVerifier)->verify('{}', null, self::SECRET));
    }

    public function test_a_tampered_payload_fails(): void
    {
        $header = $this->sign('{"amount":100}', time());

        $this->assertFalse((new StripeWebhookSignatureVerifier)->verify('{"amount":100000}', $header, self::SECRET));
    }

    public function test_the_wrong_secret_fails(): void
    {
        $payload = '{}';
        $header = $this->sign($payload, time(), 'whsec_a_different_secret');

        $this->assertFalse((new StripeWebhookSignatureVerifier)->verify($payload, $header, self::SECRET));
    }

    public function test_an_old_timestamp_outside_tolerance_fails(): void
    {
        $payload = '{}';
        $header = $this->sign($payload, time() - 600);

        $this->assertFalse((new StripeWebhookSignatureVerifier)->verify($payload, $header, self::SECRET, tolerance: 300));
    }

    public function test_a_malformed_header_fails(): void
    {
        $this->assertFalse((new StripeWebhookSignatureVerifier)->verify('{}', 'not-a-valid-header', self::SECRET));
    }
}
