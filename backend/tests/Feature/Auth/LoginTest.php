<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_log_in_with_correct_email_and_password(): void
    {
        User::factory()->create(['email' => 'jane@example.com', 'password' => Hash::make('correct-password')]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'jane@example.com',
            'password' => 'correct-password',
            'device_name' => 'iphone-15',
        ]);

        $response->assertOk()->assertJsonStructure(['user', 'token', 'token_type']);
    }

    public function test_login_fails_with_the_wrong_password(): void
    {
        User::factory()->create(['email' => 'jane@example.com', 'password' => Hash::make('correct-password')]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'jane@example.com',
            'password' => 'wrong-password',
            'device_name' => 'iphone-15',
        ]);

        $response->assertStatus(422)->assertJsonPath('error.code', 'invalid_credentials');
    }

    public function test_login_fails_for_an_unknown_email(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'nobody@example.com',
            'password' => 'whatever123',
            'device_name' => 'iphone-15',
        ]);

        $response->assertStatus(422)->assertJsonPath('error.code', 'invalid_credentials');
    }

    public function test_a_phone_only_account_cannot_log_in_with_a_password(): void
    {
        User::factory()->withPhone('+60123456789')->create(['password' => null]);

        $response = $this->postJson('/api/v1/auth/login', [
            'phone' => '+60123456789',
            'password' => 'anything123',
            'device_name' => 'iphone-15',
        ]);

        $response->assertStatus(422)->assertJsonPath('error.code', 'invalid_credentials');
    }

    /**
     * docs/06-security-architecture.md §9 "Suspend: user cannot log in" —
     * Phase 1 item 11. Every login path (password/OTP/OAuth) funnels
     * through AuthController::tokenResponse, so exercising it here covers
     * all of them.
     */
    public function test_a_suspended_user_cannot_log_in(): void
    {
        User::factory()->create([
            'email' => 'jane@example.com',
            'password' => Hash::make('correct-password'),
            'status' => 'suspended',
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'jane@example.com',
            'password' => 'correct-password',
            'device_name' => 'iphone-15',
        ]);

        $response->assertStatus(403)->assertJsonPath('error.code', 'account_suspended');
    }

    public function test_a_banned_user_cannot_log_in(): void
    {
        User::factory()->create([
            'email' => 'jane@example.com',
            'password' => Hash::make('correct-password'),
            'status' => 'banned',
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'jane@example.com',
            'password' => 'correct-password',
            'device_name' => 'iphone-15',
        ]);

        $response->assertStatus(403)->assertJsonPath('error.code', 'account_banned');
    }
}
