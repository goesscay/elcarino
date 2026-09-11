<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LogoutTest extends TestCase
{
    use RefreshDatabase;

    public function test_logout_revokes_the_current_token_only(): void
    {
        $user = User::factory()->create();
        $tokenA = $user->createToken('device-a')->plainTextToken;
        $tokenB = $user->createToken('device-b')->plainTextToken;

        $this->withHeader('Authorization', "Bearer {$tokenA}")
            ->postJson('/api/v1/auth/logout')
            ->assertOk();

        // Illuminate\Auth\RequestGuard memoizes the resolved user after the
        // first successful auth within a test, so a second simulated request
        // in the same test method would otherwise silently reuse it instead
        // of re-validating the (now-deleted) token — forgetGuards() resets
        // that between the differently-authenticated calls below.
        $this->app['auth']->forgetGuards();
        $this->withHeader('Authorization', "Bearer {$tokenA}")
            ->getJson('/api/v1/users/me')
            ->assertStatus(401);

        $this->app['auth']->forgetGuards();
        $this->withHeader('Authorization', "Bearer {$tokenB}")
            ->getJson('/api/v1/users/me')
            ->assertOk();
    }

    public function test_logout_requires_authentication(): void
    {
        $this->postJson('/api/v1/auth/logout')->assertStatus(401);
    }
}
