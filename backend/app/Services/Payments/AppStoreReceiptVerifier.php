<?php

namespace App\Services\Payments;

use Illuminate\Http\Client\Response;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;

/**
 * Apple's legacy `verifyReceipt` endpoint — still documented and functional,
 * and far simpler to wire correctly than the modern JWS-signed App Store
 * Server API, which is the better choice for a *new* integration but not
 * worth the added complexity here: this path is explicitly the
 * not-this-session's-working-default one (docs/04 item 1 — Stripe is), kept
 * real-shaped rather than a bare stub so the wiring itself is proven, but
 * genuinely unconfigured/unverified — there's no Apple Developer account or
 * shared secret on this machine to test against, same status as
 * TwilioSmsSender.
 */
class AppStoreReceiptVerifier implements ReceiptVerifier
{
    private const PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';

    private const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

    public function __construct(private readonly ?string $sharedSecret = null) {}

    public function verify(string $receipt): VerifiedReceipt
    {
        if (! $this->sharedSecret) {
            throw new ReceiptVerificationException(
                'APPLE_SHARED_SECRET is not configured — cannot verify an App Store receipt.'
            );
        }

        $response = $this->callVerifyReceipt(self::PRODUCTION_URL, $receipt);

        // Apple's documented way to distinguish a sandbox receipt sent to
        // the production endpoint: status 21007 means "retry against sandbox."
        if ($response->json('status') === 21007) {
            $response = $this->callVerifyReceipt(self::SANDBOX_URL, $receipt);
        }

        if ($response->failed() || $response->json('status') !== 0) {
            throw new ReceiptVerificationException('App Store receipt verification failed: '.$response->body());
        }

        $latest = collect($response->json('latest_receipt_info'))->last();

        if (! $latest) {
            throw new ReceiptVerificationException('App Store receipt had no latest_receipt_info entry.');
        }

        return new VerifiedReceipt(
            providerSubscriptionId: $latest['original_transaction_id'],
            expiresAt: Carbon::createFromTimestampMs((int) $latest['expires_date_ms']),
        );
    }

    private function callVerifyReceipt(string $url, string $receipt): Response
    {
        return Http::post($url, [
            'receipt-data' => $receipt,
            'password' => $this->sharedSecret,
            'exclude-old-transactions' => true,
        ]);
    }
}
