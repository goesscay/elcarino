<?php

namespace App\Services\Push;

use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Real provider (spec §18: Firebase Cloud Messaging — confirmed, not a TBD).
 * Uses FCM's HTTP v1 API — the legacy `fcm.googleapis.com/fcm/send` API
 * Google fully decommissioned in June 2024, so v1 is the only
 * currently-working option — via a service account's OAuth2 JWT-bearer
 * flow. No extra package needed beyond `firebase/php-jwt`, already a
 * dependency for Apple Sign In's token verification (`AppleTokenVerifier`).
 *
 * Untested against a real Firebase project on this machine (none
 * configured) — same status as `TwilioSmsSender`: confirm before relying on
 * this in production, and swap the `PushSender` binding in
 * `AppServiceProvider` if it doesn't check out.
 */
class FcmPushSender implements PushSender
{
    private const TOKEN_URL = 'https://oauth2.googleapis.com/token';

    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function __construct(
        private readonly ?string $projectId = null,
        private readonly ?string $serviceAccountEmail = null,
        private readonly ?string $serviceAccountPrivateKey = null,
    ) {}

    public function send(string $fcmToken, string $title, string $body, array $data = []): void
    {
        if (! $this->projectId || ! $this->serviceAccountEmail || ! $this->serviceAccountPrivateKey) {
            throw new PushSendException(
                'FCM_PROJECT_ID / FCM_SERVICE_ACCOUNT_EMAIL / FCM_SERVICE_ACCOUNT_PRIVATE_KEY are not configured. '.
                'Set them in .env, or switch PUSH_PROVIDER=log for local development.'
            );
        }

        $response = Http::withToken($this->accessToken())
            ->post("https://fcm.googleapis.com/v1/projects/{$this->projectId}/messages:send", [
                'message' => [
                    'token' => $fcmToken,
                    'notification' => ['title' => $title, 'body' => $body],
                    'data' => $data,
                ],
            ]);

        if ($response->failed()) {
            throw new PushSendException('FCM send failed: '.$response->body());
        }
    }

    /**
     * Exchanges a self-signed JWT for a short-lived OAuth2 access token
     * ("JWT Bearer Token Flow for Server to Server Applications"), cached
     * for slightly less than its real lifetime so a burst of notifications
     * doesn't mint a fresh token per send.
     */
    private function accessToken(): string
    {
        return Cache::remember('fcm_access_token', now()->addMinutes(50), function () {
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
                throw new PushSendException('FCM OAuth2 token exchange failed: '.$response->body());
            }

            return $response->json('access_token');
        });
    }

    /**
     * .env stores the PEM with literal `\n` escapes (the standard way to fit
     * a multi-line private key on one env line) — decode back to real
     * newlines before handing it to openssl via firebase/php-jwt.
     */
    private function privateKeyPem(): string
    {
        return str_replace('\\n', "\n", $this->serviceAccountPrivateKey);
    }
}
