<?php

namespace Tests\Feature\Profile;

use App\Models\Profile;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
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

    /**
     * Phase 2 item 2 (docs/06 §3.4): "Premium filters ... 403 +
     * error.code = upgrade_required."
     */
    public function test_a_free_user_cannot_set_a_religion_or_politics_filter(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        Profile::factory()->for($user)->create();

        $response = $this->putJson('/api/v1/preferences/me', [
            ...$this->validPayload,
            'religion_filter' => ['buddhist'],
        ]);

        $response->assertStatus(403)->assertJsonPath('error.code', 'upgrade_required');
        $this->assertDatabaseMissing('user_preferences', ['user_id' => $user->id]);
    }

    public function test_a_free_user_can_still_save_other_preferences_with_an_empty_advanced_filter(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        Profile::factory()->for($user)->create();

        $this->putJson('/api/v1/preferences/me', [
            ...$this->validPayload,
            'religion_filter' => [],
        ])->assertOk();

        $this->assertDatabaseHas('user_preferences', ['user_id' => $user->id]);
    }

    public function test_a_subscriber_can_set_a_religion_and_politics_filter(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        Profile::factory()->for($user)->create();
        Subscription::factory()->for($user)->for(SubscriptionPlan::factory()->create([
            'entitlements' => ['advanced_filters' => true],
        ]), 'plan')->create();

        $response = $this->putJson('/api/v1/preferences/me', [
            ...$this->validPayload,
            'religion_filter' => ['buddhist', 'atheist'],
            'politics_filter' => ['centrist'],
        ]);

        $response->assertOk();
        $response->assertJsonPath('preferences.religion_filter', ['buddhist', 'atheist']);
        $this->assertDatabaseHas('user_preferences', ['user_id' => $user->id]);
    }

    /**
     * The full-replace gotcha this behaviour specifically avoids: a lapsed
     * subscriber resubmitting an unrelated field (age range) must not be
     * blocked, or have their still-stored (but now-inert) advanced filter
     * silently deleted, just because the form resends every field.
     */
    public function test_a_lapsed_subscriber_can_still_update_unrelated_preferences(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        Profile::factory()->for($user)->create();
        $user->preferences()->create([
            ...$this->validPayload,
            'religion_filter' => ['buddhist'],
        ]);

        $response = $this->putJson('/api/v1/preferences/me', [
            ...$this->validPayload,
            'max_distance_km' => 75,
            'religion_filter' => ['buddhist'],
        ]);

        $response->assertOk();
        $response->assertJsonPath('preferences.max_distance_km', 75);
        $response->assertJsonPath('preferences.religion_filter', ['buddhist']);
    }

    public function test_a_lapsed_subscriber_cannot_change_an_advanced_filter_to_a_new_value(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        Profile::factory()->for($user)->create();
        $user->preferences()->create([
            ...$this->validPayload,
            'religion_filter' => ['buddhist'],
        ]);

        $response = $this->putJson('/api/v1/preferences/me', [
            ...$this->validPayload,
            'religion_filter' => ['muslim'],
        ]);

        $response->assertStatus(403)->assertJsonPath('error.code', 'upgrade_required');
        // Not assertDatabaseHas() with the json value inline: PostgreSQL's
        // `json` column type has no `=` operator at all (only SQLite is
        // this loose about comparing one against a string literal), so that
        // query fails outright on the CI Postgres job. Fetch and compare in
        // PHP instead — engine-portable, and this is what backend/CLAUDE.md
        // means by "PG-specific behaviour, verified by the CI Postgres job."
        $this->assertSame(['buddhist'], $user->preferences()->first()->religion_filter);
    }
}
