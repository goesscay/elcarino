<?php

namespace Tests\Feature\Matches;

use App\Models\Profile;
use App\Models\User;
use App\Models\UserMatch;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MatchTest extends TestCase
{
    use RefreshDatabase;

    private function userWithProfile(): User
    {
        $user = User::factory()->create();
        $profile = Profile::factory()->for($user)->create();
        $profile->photos()->create(['storage_path' => 'photos/x/'.$user->id.'.jpg', 'sort_order' => 0]);

        return $user;
    }

    public function test_a_guest_cannot_view_matches(): void
    {
        $this->getJson('/api/v1/matches')->assertUnauthorized();
    }

    public function test_it_lists_only_active_matches_most_recent_first(): void
    {
        $viewer = $this->userWithProfile();
        $older = $this->userWithProfile();
        $newer = $this->userWithProfile();
        $unmatchedPartner = $this->userWithProfile();

        UserMatch::factory()->between($viewer, $older)->create(['matched_at' => now()->subDays(2)]);
        UserMatch::factory()->between($viewer, $newer)->create(['matched_at' => now()]);
        UserMatch::factory()->between($viewer, $unmatchedPartner)->unmatched()->create();

        Sanctum::actingAs($viewer);
        $response = $this->getJson('/api/v1/matches')->assertOk();

        $response->assertJsonCount(2, 'matches');
        $response->assertJsonPath('matches.0.other_user.id', $newer->id);
        $response->assertJsonPath('matches.1.other_user.id', $older->id);
    }

    public function test_it_does_not_list_someone_elses_matches(): void
    {
        $userA = $this->userWithProfile();
        $userB = $this->userWithProfile();
        $stranger = $this->userWithProfile();
        UserMatch::factory()->between($userA, $userB)->create();

        Sanctum::actingAs($stranger);
        $this->getJson('/api/v1/matches')->assertOk()->assertJsonCount(0, 'matches');
    }

    public function test_a_participant_can_view_match_detail(): void
    {
        $viewer = $this->userWithProfile();
        $partner = $this->userWithProfile();
        $match = UserMatch::factory()->between($viewer, $partner)->create();

        Sanctum::actingAs($viewer);
        $this->getJson("/api/v1/matches/{$match->id}")
            ->assertOk()
            ->assertJsonPath('match.other_user.id', $partner->id);
    }

    public function test_a_non_participant_cannot_view_match_detail(): void
    {
        $userA = $this->userWithProfile();
        $userB = $this->userWithProfile();
        $stranger = $this->userWithProfile();
        $match = UserMatch::factory()->between($userA, $userB)->create();

        Sanctum::actingAs($stranger);
        $this->getJson("/api/v1/matches/{$match->id}")->assertForbidden();
    }

    public function test_a_participant_can_unmatch(): void
    {
        $viewer = $this->userWithProfile();
        $partner = $this->userWithProfile();
        $match = UserMatch::factory()->between($viewer, $partner)->create();

        Sanctum::actingAs($viewer);
        $this->deleteJson("/api/v1/matches/{$match->id}")->assertOk();

        $this->assertDatabaseHas('matches', [
            'id' => $match->id,
            'unmatched_by' => $viewer->id,
        ]);
        $this->assertNotNull($match->fresh()->unmatched_at);
    }

    public function test_a_non_participant_cannot_unmatch(): void
    {
        $userA = $this->userWithProfile();
        $userB = $this->userWithProfile();
        $stranger = $this->userWithProfile();
        $match = UserMatch::factory()->between($userA, $userB)->create();

        Sanctum::actingAs($stranger);
        $this->deleteJson("/api/v1/matches/{$match->id}")->assertForbidden();
    }

    public function test_a_match_cannot_be_unmatched_twice(): void
    {
        $viewer = $this->userWithProfile();
        $partner = $this->userWithProfile();
        $match = UserMatch::factory()->between($viewer, $partner)->unmatched()->create();

        Sanctum::actingAs($viewer);
        $this->deleteJson("/api/v1/matches/{$match->id}")->assertForbidden();
    }

    public function test_an_unmatched_match_is_excluded_from_the_active_list_after_unmatching(): void
    {
        $viewer = $this->userWithProfile();
        $partner = $this->userWithProfile();
        $match = UserMatch::factory()->between($viewer, $partner)->create();

        Sanctum::actingAs($viewer);
        $this->deleteJson("/api/v1/matches/{$match->id}")->assertOk();

        $this->getJson('/api/v1/matches')->assertOk()->assertJsonCount(0, 'matches');
    }
}
