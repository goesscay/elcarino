<?php

namespace App\Services\Auth\OAuth;

interface OAuthTokenVerifier
{
    /**
     * Verify an identity token server-side (security doc §2.3 — never trust a
     * token the client merely claims is valid).
     *
     * @throws InvalidOAuthTokenException
     */
    public function verify(string $idToken): OAuthUserPayload;
}
