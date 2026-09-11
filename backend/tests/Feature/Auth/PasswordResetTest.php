<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_forgot_password_always_responds_202_without_revealing_whether_the_email_exists(): void
    {
        $known = $this->postJson('/api/v1/auth/password/forgot', ['email' => 'unknown@example.com']);
        $known->assertStatus(202);

        User::factory()->create(['email' => 'jane@example.com']);
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'jane@example.com'])->assertStatus(202);
    }

    public function test_a_valid_token_resets_the_password_and_revokes_existing_tokens(): void
    {
        $user = User::factory()->create(['email' => 'jane@example.com', 'password' => Hash::make('old-password')]);
        $token = Password::createToken($user);
        $oldAccessToken = $user->createToken('old-device')->plainTextToken;

        $response = $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'jane@example.com',
            'token' => $token,
            'password' => 'new-password123',
            'password_confirmation' => 'new-password123',
        ]);

        $response->assertOk();
        $this->assertTrue(Hash::check('new-password123', $user->refresh()->password));

        $this->withHeader('Authorization', "Bearer {$oldAccessToken}")
            ->getJson('/api/v1/users/me')
            ->assertStatus(401);
    }

    public function test_an_invalid_token_is_rejected(): void
    {
        User::factory()->create(['email' => 'jane@example.com']);

        $response = $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'jane@example.com',
            'token' => 'not-a-real-token',
            'password' => 'new-password123',
            'password_confirmation' => 'new-password123',
        ]);

        $response->assertStatus(422)->assertJsonPath('error.code', 'invalid_reset_token');
    }
}
