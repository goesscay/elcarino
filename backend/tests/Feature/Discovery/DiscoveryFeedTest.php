<?php

namespace Tests\Feature\Discovery;

use App\Models\Block;
use App\Models\Profile;
use App\Models\Swipe;
use App\Models\User;
use App\Models\UserLocation;
use App\Models\UserPreference;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DiscoveryFeedTest extends TestCase
{
    use RefreshDatabase;

    /**
     * A fully onboarded, discoverable candidate: profile + a photo +
     * location, at an offset (in whole degrees, ~111 km/degree) from central
     * Kuala Lumpur (3.139, 101.687) so distance filtering is exercisable.
     */
    private function makeCandidate(
        string $gender = 'woman',
        int $age = 28,
        float $latOffset = 0.0,
        float $lonOffset = 0.0,
        ?string $relationshipGoal = null,
    ): User {
        $user = User::factory()->create();
        $profile = Profile::factory()->for($user)->create([
            'gender' => $gender,
            'birth_date' => now()->subYears($age)->subDays(10),
            'relationship_goal' => $relationshipGoal,
        ]);
        $profile->photos()->create(['storage_path' => 'photos/x/'.$user->id.'.jpg', 'sort_order' => 0]);
        UserLocation::factory()->for($user)->at(3.139 + $latOffset, 101.687 + $lonOffset)->create();

        return $user;
    }

    private function setViewer(
        string $gender = 'man',
        array $interestedIn = ['woman'],
        int $minAge = 21,
        int $maxAge = 40,
        int $maxDistanceKm = 50,
        array $relationshipGoalFilter = [],
    ): User {
        $viewer = User::factory()->create();
        Profile::factory()->for($viewer)->create(['gender' => $gender]);
        UserLocation::factory()->for($viewer)->at(3.139, 101.687)->create();
        UserPreference::factory()->for($viewer)->create([
            'min_age' => $minAge,
            'max_age' => $maxAge,
            'max_distance_km' => $maxDistanceKm,
            'interested_in_genders' => $interestedIn,
            'relationship_goal_filter' => $relationshipGoalFilter,
        ]);
        Sanctum::actingAs($viewer);

        return $viewer;
    }

    public function test_a_guest_cannot_view_the_feed(): void
    {
        $this->getJson('/api/v1/discovery/feed')->assertUnauthorized();
    }

    public function test_it_requires_a_location_to_be_set(): void
    {
        $viewer = User::factory()->create();
        Profile::factory()->for($viewer)->create();
        UserPreference::factory()->for($viewer)->create();
        Sanctum::actingAs($viewer);

        $this->getJson('/api/v1/discovery/feed')
            ->assertStatus(422)->assertJsonPath('error.code', 'location_required');
    }

    public function test_it_requires_preferences_to_be_set(): void
    {
        $viewer = User::factory()->create();
        Profile::factory()->for($viewer)->create();
        UserLocation::factory()->for($viewer)->create();
        Sanctum::actingAs($viewer);

        $this->getJson('/api/v1/discovery/feed')
            ->assertStatus(422)->assertJsonPath('error.code', 'preferences_required');
    }

    public function test_it_returns_a_nearby_matching_candidate(): void
    {
        $this->setViewer();
        $this->makeCandidate(gender: 'woman', age: 25, latOffset: 0.05);

        $response = $this->getJson('/api/v1/discovery/feed')->assertOk();

        $response->assertJsonCount(1, 'candidates');
        $response->assertJsonStructure([
            'candidates' => [['id', 'display_name', 'age', 'bio', 'is_verified', 'distance_km', 'photos', 'prompts']],
            'meta' => ['page', 'per_page', 'has_more'],
        ]);
    }

    public function test_it_excludes_a_candidate_of_the_wrong_gender(): void
    {
        $this->setViewer(interestedIn: ['woman']);
        $this->makeCandidate(gender: 'man');

        $this->getJson('/api/v1/discovery/feed')->assertOk()->assertJsonCount(0, 'candidates');
    }

    public function test_it_excludes_a_candidate_outside_the_age_range(): void
    {
        $this->setViewer(minAge: 25, maxAge: 30);
        $this->makeCandidate(age: 45);

        $this->getJson('/api/v1/discovery/feed')->assertOk()->assertJsonCount(0, 'candidates');
    }

    public function test_it_excludes_a_candidate_beyond_the_max_distance(): void
    {
        $this->setViewer(maxDistanceKm: 50);
        // ~1 degree of latitude is ~111 km — well outside a 50 km radius.
        $this->makeCandidate(latOffset: 1.0);

        $this->getJson('/api/v1/discovery/feed')->assertOk()->assertJsonCount(0, 'candidates');
    }

    public function test_it_excludes_a_candidate_with_no_photos_yet(): void
    {
        $viewer = $this->setViewer();
        $candidateNoPhoto = User::factory()->create();
        Profile::factory()->for($candidateNoPhoto)->create(['gender' => 'woman']);
        UserLocation::factory()->for($candidateNoPhoto)->at(3.139, 101.687)->create();

        $this->getJson('/api/v1/discovery/feed')->assertOk()->assertJsonCount(0, 'candidates');
    }

    public function test_it_excludes_an_already_swiped_candidate(): void
    {
        $viewer = $this->setViewer();
        $candidate = $this->makeCandidate();
        Swipe::factory()->create(['actor_id' => $viewer->id, 'target_id' => $candidate->id, 'direction' => 'left']);

        $this->getJson('/api/v1/discovery/feed')->assertOk()->assertJsonCount(0, 'candidates');
    }

    public function test_it_excludes_a_candidate_the_viewer_blocked(): void
    {
        $viewer = $this->setViewer();
        $candidate = $this->makeCandidate();
        Block::factory()->create(['blocker_id' => $viewer->id, 'blocked_id' => $candidate->id]);

        $this->getJson('/api/v1/discovery/feed')->assertOk()->assertJsonCount(0, 'candidates');
    }

    public function test_it_excludes_a_candidate_who_blocked_the_viewer(): void
    {
        $viewer = $this->setViewer();
        $candidate = $this->makeCandidate();
        Block::factory()->create(['blocker_id' => $candidate->id, 'blocked_id' => $viewer->id]);

        $this->getJson('/api/v1/discovery/feed')->assertOk()->assertJsonCount(0, 'candidates');
    }

    public function test_it_filters_by_relationship_goal_when_the_viewer_set_one(): void
    {
        $this->setViewer(relationshipGoalFilter: ['Long-term']);
        $this->makeCandidate(relationshipGoal: 'Casual');
        $this->makeCandidate(relationshipGoal: 'Long-term');

        $response = $this->getJson('/api/v1/discovery/feed')->assertOk();

        $response->assertJsonCount(1, 'candidates');
        $response->assertJsonPath('candidates.0.relationship_goal', 'Long-term');
    }

    public function test_results_are_sorted_by_distance_ascending(): void
    {
        $this->setViewer(maxDistanceKm: 200);
        $this->makeCandidate(latOffset: 0.3); // farther
        $this->makeCandidate(latOffset: 0.05); // nearer

        $response = $this->getJson('/api/v1/discovery/feed')->assertOk();

        $distances = collect($response->json('candidates'))->pluck('distance_km')->all();
        $sorted = $distances;
        sort($sorted);
        $this->assertSame($sorted, $distances);
    }

    public function test_pagination_respects_per_page_and_reports_has_more(): void
    {
        $this->setViewer(maxDistanceKm: 200);
        for ($i = 0; $i < 3; $i++) {
            $this->makeCandidate(latOffset: 0.01 * $i);
        }

        $response = $this->getJson('/api/v1/discovery/feed?per_page=2')->assertOk();

        $response->assertJsonCount(2, 'candidates');
        $response->assertJsonPath('meta.has_more', true);

        $secondPage = $this->getJson('/api/v1/discovery/feed?per_page=2&page=2')->assertOk();
        $secondPage->assertJsonCount(1, 'candidates');
        $secondPage->assertJsonPath('meta.has_more', false);
    }
}
