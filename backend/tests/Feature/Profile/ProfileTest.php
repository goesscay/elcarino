<?php

namespace Tests\Feature\Profile;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_view_or_update_a_profile(): void
    {
        $this->getJson('/api/v1/profiles/me')->assertUnauthorized();
        $this->putJson('/api/v1/profiles/me', [])->assertUnauthorized();
    }

    public function test_get_profile_404s_before_it_has_been_created(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/profiles/me')
            ->assertStatus(404)
            ->assertJsonPath('error.code', 'profile_not_found');
    }

    public function test_a_user_can_create_their_profile_basics(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $response = $this->putJson('/api/v1/profiles/me', [
            'display_name' => 'Jane',
            'birth_date' => '1995-06-15',
            'gender' => 'woman',
            'bio' => 'Say hi!',
        ]);

        $response->assertOk()->assertJsonPath('profile.display_name', 'Jane');
        // Basics only (no photos/prompts/preferences yet) — 40% per the
        // documented weighting in Profile::recalculateCompletion().
        $response->assertJsonPath('profile.completion_pct', 40);

        $this->assertDatabaseHas('profiles', [
            'user_id' => $user->id,
            'display_name' => 'Jane',
            'gender' => 'woman',
        ]);
    }

    public function test_updating_an_existing_profile_does_not_create_a_duplicate_row(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $this->putJson('/api/v1/profiles/me', [
            'display_name' => 'Jane', 'birth_date' => '1995-06-15', 'gender' => 'woman',
        ])->assertOk();
        $this->putJson('/api/v1/profiles/me', [
            'display_name' => 'Janet', 'birth_date' => '1995-06-15', 'gender' => 'woman',
        ])->assertOk()->assertJsonPath('profile.display_name', 'Janet');

        $this->assertSame(1, $user->profile()->count());
    }

    public function test_profile_creation_enforces_the_18_plus_age_gate(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $under18 = now()->subYears(17)->format('Y-m-d');

        $this->putJson('/api/v1/profiles/me', [
            'display_name' => 'Too Young', 'birth_date' => $under18, 'gender' => 'woman',
        ])->assertStatus(422)->assertJsonValidationErrors('birth_date');
    }

    public function test_profile_rejects_a_gender_outside_the_confirmed_enum(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/v1/profiles/me', [
            'display_name' => 'Jane', 'birth_date' => '1995-06-15', 'gender' => 'robot',
        ])->assertStatus(422)->assertJsonValidationErrors('gender');
    }

    /**
     * Phase 2 item 2: anyone can state their own religion/politics for
     * free — only *filtering* other people by it is premium-gated
     * (PreferenceTest covers that side).
     */
    public function test_a_free_user_can_set_their_own_religion_and_politics(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $response = $this->putJson('/api/v1/profiles/me', [
            'display_name' => 'Jane',
            'birth_date' => '1995-06-15',
            'gender' => 'woman',
            'religion' => 'buddhist',
            'politics' => 'centrist',
        ]);

        $response->assertOk();
        $response->assertJsonPath('profile.religion', 'buddhist');
        $response->assertJsonPath('profile.politics', 'centrist');
        $this->assertDatabaseHas('profiles', ['user_id' => $user->id, 'religion' => 'buddhist', 'politics' => 'centrist']);
    }
}
