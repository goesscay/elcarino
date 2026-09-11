<?php

namespace App\Services\Auth\OAuth;

use Illuminate\Support\Facades\Http;

/**
 * Verifies a Google ID token server-side via Google's tokeninfo endpoint.
 *
 * This is Google's documented server-side verification method and avoids
 * pulling in a JWT/JWKS library for Phase 1. It costs one extra HTTP round
 * trip per login versus local signature verification against Google's JWKS —
 * acceptable for MVP traffic; revisit if it becomes a bottleneck.
 */
class GoogleTokenVerifier implements OAuthTokenVerifier
{
    public function __construct(private readonly ?string $clientId = null) {}

    public function verify(string $idToken): OAuthUserPayload
    {
        $response = Http::get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $idToken]);

        if ($response->failed()) {
            throw new InvalidOAuthTokenException('Google rejected the ID token.');
        }

        $payload = $response->json();

        if ($this->clientId !== null && ($payload['aud'] ?? null) !== $this->clientId) {
            throw new InvalidOAuthTokenException('Google ID token audience mismatch.');
        }

        if (empty($payload['sub'])) {
            throw new InvalidOAuthTokenException('Google ID token missing subject claim.');
        }

        return new OAuthUserPayload(
            providerUserId: $payload['sub'],
            email: ($payload['email_verified'] ?? false) ? ($payload['email'] ?? null) : null,
        );
    }
}
