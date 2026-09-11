<?php

namespace App\Services\Auth\OAuth;

/**
 * Verified identity extracted from a provider's ID token. Never constructed
 * from unverified client input — only ever returned by an OAuthTokenVerifier
 * after signature/audience verification has passed.
 */
final class OAuthUserPayload
{
    public function __construct(
        public readonly string $providerUserId,
        public readonly ?string $email,
    ) {}
}
