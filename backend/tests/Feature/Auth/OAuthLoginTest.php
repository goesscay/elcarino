<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Firebase\JWT\JWT;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class OAuthLoginTest extends TestCase
{
    use RefreshDatabase;

    // ---- Google (verified via a live HTTP call to Google's tokeninfo endpoint) ----

    public function test_google_login_creates_a_new_user(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/*' => Http::response([
                'sub' => 'google-uid-123',
                'email' => 'jane@example.com',
                'email_verified' => 'true',
                'aud' => 'test-client-id',
            ]),
        ]);

        $response = $this->postJson('/api/v1/auth/oauth/google', [
            'id_token' => 'fake-id-token',
            'device_name' => 'iphone-15',
        ]);

        $response->assertOk()->assertJsonStructure(['user', 'token', 'token_type']);
        $this->assertDatabaseHas('users', ['google_id' => 'google-uid-123', 'email' => 'jane@example.com']);
    }

    public function test_google_login_rejects_a_token_google_does_not_recognise(): void
    {
        Http::fake(['https://oauth2.googleapis.com/*' => Http::response(['error' => 'invalid_token'], 400)]);

        $response = $this->postJson('/api/v1/auth/oauth/google', [
            'id_token' => 'garbage',
            'device_name' => 'iphone-15',
        ]);

        $response->assertStatus(422)->assertJsonPath('error.code', 'invalid_oauth_token');
    }

    public function test_google_login_links_an_existing_account_with_the_same_verified_email(): void
    {
        $user = User::factory()->create(['email' => 'jane@example.com']);

        Http::fake([
            'https://oauth2.googleapis.com/*' => Http::response([
                'sub' => 'google-uid-999',
                'email' => 'jane@example.com',
                'email_verified' => 'true',
            ]),
        ]);

        $this->postJson('/api/v1/auth/oauth/google', [
            'id_token' => 'fake-id-token',
            'device_name' => 'iphone-15',
        ])->assertOk();

        $this->assertSame(1, User::query()->where('email', 'jane@example.com')->count());
        $this->assertSame('google-uid-999', $user->refresh()->google_id);
    }

    // ---- Apple (verified via a real RS256-signed JWT against a faked JWKS response) ----

    public function test_apple_login_creates_a_new_user(): void
    {
        [$idToken, $jwks] = $this->makeSignedAppleToken([
            'iss' => 'https://appleid.apple.com',
            'sub' => 'apple-uid-123',
            'aud' => 'com.mgs.elcarino',
            'email' => 'jane@icloud.com',
            'email_verified' => true,
            'exp' => now()->addMinutes(5)->timestamp,
            'iat' => now()->timestamp,
        ]);
        Http::fake(['https://appleid.apple.com/auth/keys' => Http::response($jwks)]);

        $response = $this->postJson('/api/v1/auth/oauth/apple', [
            'id_token' => $idToken,
            'device_name' => 'iphone-15',
        ]);

        $response->assertOk();
        $this->assertDatabaseHas('users', ['apple_id' => 'apple-uid-123', 'email' => 'jane@icloud.com']);
    }

    public function test_apple_login_rejects_a_token_with_the_wrong_issuer(): void
    {
        [$idToken, $jwks] = $this->makeSignedAppleToken([
            'iss' => 'https://not-apple.example',
            'sub' => 'apple-uid-123',
            'aud' => 'com.mgs.elcarino',
            'exp' => now()->addMinutes(5)->timestamp,
            'iat' => now()->timestamp,
        ]);
        Http::fake(['https://appleid.apple.com/auth/keys' => Http::response($jwks)]);

        $this->postJson('/api/v1/auth/oauth/apple', [
            'id_token' => $idToken,
            'device_name' => 'iphone-15',
        ])->assertStatus(422)->assertJsonPath('error.code', 'invalid_oauth_token');
    }

    /**
     * Generates a real RS256-signed JWT plus a matching JWKS document, so the
     * test exercises AppleTokenVerifier's actual signature/issuer/audience
     * checks rather than stubbing them out.
     *
     * @return array{0: string, 1: array}
     */
    private function makeSignedAppleToken(array $claims): array
    {
        // openssl_pkey_new()/export() need a parseable openssl.cnf, which the
        // Windows PHP build used for local dev doesn't ship with one at its
        // default location. An empty file at an explicit path satisfies it
        // (we're not using any config-driven features, just RSA keygen) and
        // keeps the test independent of what's installed on the machine.
        $opensslConfig = tempnam(sys_get_temp_dir(), 'openssl-empty-').'.cnf';
        file_put_contents($opensslConfig, '');
        $options = ['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA, 'config' => $opensslConfig];

        $keyPair = openssl_pkey_new($options);
        openssl_pkey_export($keyPair, $privateKeyPem, null, $options);
        $details = openssl_pkey_get_details($keyPair);
        unlink($opensslConfig);

        $kid = 'test-key-1';
        $jwt = JWT::encode($claims, $privateKeyPem, 'RS256', $kid);

        $jwks = ['keys' => [[
            'kty' => 'RSA',
            'kid' => $kid,
            'use' => 'sig',
            'alg' => 'RS256',
            'n' => JWT::urlsafeB64Encode($details['rsa']['n']),
            'e' => JWT::urlsafeB64Encode($details['rsa']['e']),
        ]]];

        return [$jwt, $jwks];
    }
}
