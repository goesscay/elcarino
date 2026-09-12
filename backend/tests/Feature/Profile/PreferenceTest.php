<?php

namespace Tests\Feature\Profile;

use App\Models\Profile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PreferenceTest extends TestCase
{
    use RefreshDatabase;

    private array $validPayload = [
        'min_age' => 21,
        'max_age' => 40,
        'max_distance_km' => 50,
        'interested_in_genders' => ['woman', 'non_binary'],
    ];

    public function test_a_guest_cannot_view_or_update_preferences(): void
    {
        $this->getJson('/api/v1/preferences/me')->assertUnauthorized();
        $this->putJson('/api/v1/preferences/me', [])->assertUnauthorized();
    }

    public function test_get_preferences_404s_before_they_have_been_set(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/preferences/me')
            ->assertStatus(404)->assertJsonPath('error.code', 'preferences_not_found');
    }

    public function test_a_user_can_set_preferences(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        Profile::factory()->for($user)->create();

        $response = $this->putJson('/api/v1/preferences/me', $this->validPayload);

        $response->assertOk()->assertJsonPath('preferences.max_distance_km', 50);
        $this->assertDatabaseHas('user_preferences', ['user_id' => $user->id, 'min_age' => 21]);
        // completion_pct: basics (40) + preferences saved (15) = 55.
        $this->assertSame(55, $user->profile()->first()->completion_pct);
    }

    public function test_it_rejects_max_age_below_min_age(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/v1/preferences/me', [...$this->validPayload, 'min_age' => 40, 'max_age' => 30])
            ->assertStatus(422)->assertJsonValidationErrors('max_age');
    }

    public function test_it_rejects_a_distance_over_the_platform_cap(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/v1/preferences/me', [...$this->validPayload, 'max_distance_km' => 201])
            ->assertStatus(422)->assertJsonValidationErrors('max_distance_km');
    }

    public function test_it_requires_at_least_one_interested_in_gender(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/v1/preferences/me', [...$this->validPayload, 'interested_in_genders' => []])
            ->assertStatus(422)->assertJsonValidationErrors('interested_in_genders');
    }
}
