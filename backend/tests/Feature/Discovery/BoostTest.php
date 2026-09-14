<?php

namespace Tests\Feature\Discovery;

use App\Models\Boost;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BoostTest extends TestCase
{
    use RefreshDatabase;

    private function subscriber(int $boostsPerMonth = 1): User
    {
        $user = User::factory()->create();
        $plan = SubscriptionPlan::factory()->create(['entitlements' => ['boosts_per_month' => $boostsPerMonth]]);
        Subscription::factory()->for($user)->for($plan, 'plan')->create();

        return $user;
    }

    public function test_a_guest_cannot_use_either_boost_endpoint(): void
    {
        $this->getJson('/api/v1/discovery/boost')->assertUnauthorized();
        $this->postJson('/api/v1/discovery/boost')->assertUnauthorized();
    }

    public function test_status_before_activating_anything(): void
    {
        Sanctum::actingAs($this->subscriber(2));

        $response = $this->getJson('/api/v1/discovery/boost')->assertOk();

        $response->assertJson(['active' => false, 'ends_at' => null, 'used_this_month' => 0, 'limit' => 2]);
    }

    public function test_a_subscriber_can_activate_a_boost(): void
    {
        Sanctum::actingAs($user = $this->subscriber());

        $response = $this->postJson('/api/v1/discovery/boost');

        $response->assertCreated();
        $response->assertJsonStructure(['starts_at', 'ends_at']);
        $this->assertDatabaseHas('boosts', ['user_id' => $user->id]);

        $status = $this->getJson('/api/v1/discovery/boost')->assertOk();
        $status->assertJson(['active' => true, 'used_this_month' => 1]);
    }

    public function test_a_free_user_gets_upgrade_required(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/discovery/boost')
            ->assertStatus(403)->assertJsonPath('error.code', 'upgrade_required');
    }

    public function test_activating_twice_returns_a_conflict(): void
    {
        Sanctum::actingAs($this->subscriber());

        $this->postJson('/api/v1/discovery/boost')->assertCreated();

        $this->postJson('/api/v1/discovery/boost')
            ->assertStatus(409)->assertJsonPath('error.code', 'boost_already_active');
    }

    public function test_the_monthly_limit_is_enforced(): void
    {
        Sanctum::actingAs($user = $this->subscriber(1));
        Boost::factory()->for($user)->expired()->create();

        $this->postJson('/api/v1/discovery/boost')
            ->assertStatus(403)->assertJsonPath('error.code', 'boost_limit_reached');
    }
}
