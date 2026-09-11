<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class RegistrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_register_with_email_and_password(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'email' => 'jane@example.com',
            'password' => 'password123',
            'device_name' => 'iphone-15',
        ]);

        $response->assertCreated()->assertJsonStructure([
            'user' => ['id', 'email', 'status'],
            'token',
            'token_type',
        ]);

        $this->assertDatabaseHas('users', ['email' => 'jane@example.com']);
        $this->assertTrue(Hash::check(
            'password123',
            User::query()->where('email', 'jane@example.com')->firstOrFail()->password,
        ));
    }

    public function test_registration_fails_with_a_duplicate_email(): void
    {
        User::factory()->create(['email' => 'taken@example.com']);

        $response = $this->postJson('/api/v1/auth/register', [
            'email' => 'taken@example.com',
            'password' => 'password123',
            'device_name' => 'iphone-15',
        ]);

        $response->assertStatus(422)->assertJsonValidationErrors('email');
    }

    public function test_registration_fails_with_a_weak_password(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'email' => 'weak@example.com',
            'password' => 'alllowercase',
            'device_name' => 'iphone-15',
        ]);

        $response->assertStatus(422)->assertJsonValidationErrors('password');
        $this->assertDatabaseMissing('users', ['email' => 'weak@example.com']);
    }
}
