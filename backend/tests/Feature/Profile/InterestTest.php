<?php

namespace Tests\Feature\Profile;

use App\Models\Interest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class InterestTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_list_or_select_interests(): void
    {
        $this->getJson('/api/v1/interests')->assertUnauthorized();
        $this->putJson('/api/v1/interests/me', [])->assertUnauthorized();
    }

    public function test_it_lists_the_full_catalogue(): void
    {
        Interest::factory()->count(3)->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/interests')->assertOk()->assertJsonCount(3, 'interests');
    }

    public function test_a_user_can_select_interests(): void
    {
        [$running, $coffee] = Interest::factory()->count(2)->create();
        Sanctum::actingAs($user = User::factory()->create());

        $response = $this->putJson('/api/v1/interests/me', [
            'interest_ids' => [$running->id, $coffee->id],
        ]);

        $response->assertOk()->assertJsonCount(2, 'interests');
        $this->assertSame(2, $user->interests()->count());
    }

    public function test_selecting_replaces_the_previous_set(): void
    {
        [$running, $coffee] = Interest::factory()->count(2)->create();
        Sanctum::actingAs($user = User::factory()->create());

        $this->putJson('/api/v1/interests/me', ['interest_ids' => [$running->id]])->assertOk();
        $this->putJson('/api/v1/interests/me', ['interest_ids' => [$coffee->id]])->assertOk();

        $this->assertSame(1, $user->interests()->count());
        $this->assertTrue($user->interests()->where('interests.id', $coffee->id)->exists());
    }

    public function test_an_empty_selection_clears_all_interests(): void
    {
        $interest = Interest::factory()->create();
        Sanctum::actingAs($user = User::factory()->create());
        $user->interests()->attach($interest->id);

        $this->putJson('/api/v1/interests/me', ['interest_ids' => []])->assertOk();

        $this->assertSame(0, $user->interests()->count());
    }

    public function test_it_rejects_an_interest_id_that_does_not_exist(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/v1/interests/me', ['interest_ids' => [999999]])
            ->assertStatus(422)->assertJsonValidationErrors('interest_ids.0');
    }

    public function test_it_rejects_more_than_the_configured_max(): void
    {
        $interests = Interest::factory()->count(config('media.max_interests_per_profile') + 1)->create();
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/v1/interests/me', ['interest_ids' => $interests->pluck('id')->all()])
            ->assertStatus(422)->assertJsonValidationErrors('interest_ids');
    }

    public function test_a_user_can_see_their_own_selected_interests(): void
    {
        $interest = Interest::factory()->create(['name' => 'Hiking']);
        Sanctum::actingAs($user = User::factory()->create());
        $user->interests()->attach($interest->id);

        $this->getJson('/api/v1/interests/me')
            ->assertOk()
            ->assertJsonCount(1, 'interests')
            ->assertJsonPath('interests.0.name', 'Hiking');
    }
}
