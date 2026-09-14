<?php

namespace Tests\Unit\Services\Payments;

use App\Services\Payments\AppStoreReceiptVerifier;
use App\Services\Payments\ReceiptVerificationException;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Not verified against a real Apple Developer account (none configured) —
 * same status as TwilioSmsSender. This asserts the wiring: request shape,
 * response parsing, and the sandbox-retry-on-21007 behaviour Apple's own
 * docs describe. Extends the Laravel TestCase (not plain PHPUnit) because
 * `Http::fake()` needs the application container booted.
 */
class AppStoreReceiptVerifierTest extends TestCase
{
    public function test_it_throws_when_unconfigured(): void
    {
        $this->expectException(ReceiptVerificationException::class);
        (new AppStoreReceiptVerifier)->verify('receipt-blob');
    }

    public function test_a_valid_receipt_returns_a_verified_receipt(): void
    {
        Http::fake([
            'https://buy.itunes.apple.com/verifyReceipt' => Http::response([
                'status' => 0,
                'latest_receipt_info' => [
                    ['original_transaction_id' => '1000000123', 'expires_date_ms' => '1999999999000'],
                ],
            ]),
        ]);

        $verified = (new AppStoreReceiptVerifier('shared-secret'))->verify('receipt-blob');

        $this->assertSame('1000000123', $verified->providerSubscriptionId);
        $this->assertSame(1999999999, $verified->expiresAt->getTimestamp());
    }

    public function test_status_21007_retries_against_the_sandbox_endpoint(): void
    {
        Http::fake([
            'https://buy.itunes.apple.com/verifyReceipt' => Http::response(['status' => 21007]),
            'https://sandbox.itunes.apple.com/verifyReceipt' => Http::response([
                'status' => 0,
                'latest_receipt_info' => [['original_transaction_id' => 'sandbox-1', 'expires_date_ms' => '1999999999000']],
            ]),
        ]);

        $verified = (new AppStoreReceiptVerifier('shared-secret'))->verify('receipt-blob');

        $this->assertSame('sandbox-1', $verified->providerSubscriptionId);
    }

    public function test_a_non_zero_status_throws(): void
    {
        Http::fake(['https://buy.itunes.apple.com/verifyReceipt' => Http::response(['status' => 21002])]);

        $this->expectException(ReceiptVerificationException::class);
        (new AppStoreReceiptVerifier('shared-secret'))->verify('receipt-blob');
    }
}
