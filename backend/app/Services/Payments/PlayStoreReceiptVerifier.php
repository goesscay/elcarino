<?php

namespace App\Services\Payments;

use Firebase\JWT\JWT;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Google Play Developer API (`purchases.subscriptions.get`) via a service
 * account's OAuth2 JWT-bearer flow — the exact same grant type
 * FcmPushSender already uses for Firebase, just a different scope, reusing
 * `firebase/php-jwt` rather than adding a second JWT dependency for one
 * more Google API.
 *
 * `$receipt` here is a JSON string `{"package_name", "subscription_id",
 * "purchase_token"}` — Play's verification call needs all three, unlike
 * Apple's single opaque receipt blob, so there's no single "the receipt"
 * to just forward. Genuinely unconfigured/unverified — no Play Console
 * service account exists on this machine, same status as
 * AppStoreReceiptVerifier/TwilioSmsSender.
 */
class PlayStoreReceiptVerifier implements ReceiptVerifier
{
    private const TOKEN_URL = 'https://oauth2.googleapis.com/token';

    private const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

    public function __construct(
        private readonly ?string $serviceAccountEmail = null,
        private readonly ?string $serviceAccountPrivateKey = null,
    ) {}

    public function verify(string $receipt): VerifiedReceipt
    {
        if (! $this->serviceAccountEmail || ! $this->serviceAccountPrivateKey) {
            throw new ReceiptVerificationException(
                'PLAY_SERVICE_ACCOUNT_EMAIL / PLAY_SERVICE_ACCOUNT_PRIVATE_KEY are not configured — cannot verify a Play Store purchase.'
            );
        }

        $payload = json_decode($receipt, associative: true);
        if (! is_array($payload) || ! isset($payload['package_name'], $payload['subscription_id'], $payload['purchase_token'])) {
            throw new ReceiptVerificationException('Play Store receipt must be JSON with package_name, subscription_id, purchase_token.');
        }

        $url = sprintf(
            'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/%s/purchases/subscriptions/%s/tokens/%s',
            $payload['package_name'],
            $payload['subscription_id'],
            $payload['purchase_token'],
        );

        $response = Http::withToken($this->accessToken())->get($url);

        if ($response->failed()) {
            throw new ReceiptVerificationException('Play Store purchase verification failed: '.$response->body());
        }

        $expiryMs = $response->json('expiryTimeMillis');
        if (! $expiryMs) {
            throw new ReceiptVerificationException('Play Store response had no expiryTimeMillis.');
        }

        return new VerifiedReceipt(
            providerSubscriptionId: $payload['purchase_token'],
            expiresAt: Carbon::createFromTimestampMs((int) $expiryMs),
        );
    }

    private function accessToken(): string
    {
        return Cache::remember('play_store_access_token', now()->addMinutes(50), function () {
            $now = time();
            $assertion = JWT::encode([
                'iss' => $this->serviceAccountEmail,
                'scope' => self::SCOPE,
                'aud' => self::TOKEN_URL,
                'iat' => $now,
                'exp' => $now + 3600,
            ], $this->privateKeyPem(), 'RS256');

            $response = Http::asForm()->post(self::TOKEN_URL, [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $assertion,
            ]);

            if ($response->failed()) {
                throw new ReceiptVerificationException('Play Store OAuth2 token exchange failed: '.$response->body());
            }

            return $response->json('access_token');
        });
    }

    private function privateKeyPem(): string
    {
        return str_replace('\\n', "\n", $this->serviceAccountPrivateKey);
    }
}
