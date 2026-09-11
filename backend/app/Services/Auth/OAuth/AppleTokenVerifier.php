<?php

namespace App\Services\Auth\OAuth;

use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use UnexpectedValueException;

/**
 * Verifies an Apple identity token server-side against Apple's published
 * JWKS (Apple has no tokeninfo endpoint like Google's, so real signature
 * verification is required — security doc §2.3).
 */
class AppleTokenVerifier implements OAuthTokenVerifier
{
    private const JWKS_URL = 'https://appleid.apple.com/auth/keys';

    private const ISSUER = 'https://appleid.apple.com';

    public function __construct(private readonly ?string $clientId = null) {}

    public function verify(string $idToken): OAuthUserPayload
    {
        $keys = Cache::remember('apple_oauth_jwks', now()->addHours(6), function () {
            $response = Http::get(self::JWKS_URL);

            if ($response->failed()) {
                throw new InvalidOAuthTokenException('Unable to fetch Apple JWKS.');
            }

            return $response->json();
        });

        try {
            $decoded = JWT::decode($idToken, JWK::parseKeySet($keys));
        } catch (UnexpectedValueException $e) {
            throw new InvalidOAuthTokenException('Apple ID token failed verification: '.$e->getMessage());
        }

        if ($decoded->iss !== self::ISSUER) {
            throw new InvalidOAuthTokenException('Apple ID token issuer mismatch.');
        }

        if ($this->clientId !== null && $decoded->aud !== $this->clientId) {
            throw new InvalidOAuthTokenException('Apple ID token audience mismatch.');
        }

        if (empty($decoded->sub)) {
            throw new InvalidOAuthTokenException('Apple ID token missing subject claim.');
        }

        return new OAuthUserPayload(
            providerUserId: $decoded->sub,
            email: ($decoded->email_verified ?? false) ? ($decoded->email ?? null) : null,
        );
    }
}
