<?php

namespace Tests\Feature\Explore;

use App\Enums\SwipeDirection;
use App\Enums\UserStatus;
use App\Models\Block;
use App\Models\Interest;
use App\Models\Profile;
use App\Models\Swipe;
use App\Models\User;
use App\Models\UserLocation;
use App\Models\UserPreference;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * `GET /explore/interests` and `.../{interest}/people`. Explore is built on the
 * discovery feed's own eligibility, so the property under test throughout is
 * that it never counts or lists someone the feed itself would hide.
 */
class ExploreTest extends TestCase
{
    use RefreshDatabase;

    private function person(string $name = 'Someone', string $gender = 'woman', int $age = 28, float $latOffset = 0.0): User
    {
        $user = User::factory()->create();
        $profile = Profile::factory()->for($user)->create([
            'display_name' => $name,
            'gender' => $gender,
            'birth_date' => now()->subYears($age)->subDays(10),
        ]);
        $profile->photos()->create(['storage_path' => 'photos/x/'.$user->id.'.jpg', 'sort_order' => 0]);
        UserLocation::factory()->for($user)->at(3.139 + $latOffset, 101.687)->create();

        return $user;
    }

    /**
     * @param  list<Interest>  $interests
     */
    private function personWith(array $interests, string $name = 'Someone', string $gender = 'woman', int $age = 28, float $latOffset = 0.0): User
    {
        $user = $this->person($name, $gender, $age, $latOffset);
        $user->interests()->attach(collect($interests)->pluck('id'));

        return $user;
    }

    private function viewer(int $maxDistanceKm = 50): User
    {
        $viewer = User::factory()->create();
        Profile::factory()->for($viewer)->create(['gender' => 'man']);
        UserLocation::factory()->for($viewer)->at(3.139, 101.687)->create();
        UserPreference::factory()->for($viewer)->create([
            'min_age' => 21,
            'max_age' => 40,
            'max_distance_km' => $maxDistanceKm,
            'interested_in_genders' => ['woman'],
            'relationship_goal_filter' => [],
        ]);
        Sanctum::actingAs($viewer);

        return $viewer;
    }

    private function interest(string $name, string $category = 'Lifestyle'): Interest
    {
        return Interest::factory()->create(['name' => $name, 'category' => $category]);
    }

    public function test_a_guest_cannot_use_either_endpoint(): void
    {
        $interest = $this->interest('Coffee');

        $this->getJson('/api/v1/explore/interests')->assertUnauthorized();
        $this->getJson("/api/v1/explore/interests/{$interest->id}/people")->assertUnauthorized();
    }

    public function test_it_needs_a_location_and_preferences_like_the_feed(): void
    {
        $noLocation = User::factory()->create();
        Profile::factory()->for($noLocation)->create();
        UserPreference::factory()->for($noLocation)->create();
        Sanctum::actingAs($noLocation);
        $this->getJson('/api/v1/explore/interests')
            ->assertStatus(422)->assertJsonPath('error.code', 'location_required');

        $noPreferences = User::factory()->create();
        Profile::factory()->for($noPreferences)->create();
        UserLocation::factory()->for($noPreferences)->create();
        Sanctum::actingAs($noPreferences);
        $this->getJson('/api/v1/explore/interests')
            ->assertStatus(422)->assertJsonPath('error.code', 'preferences_required');
    }

    public function test_interests_are_counted_most_popular_first_then_by_name(): void
    {
        $this->viewer();
        $coffee = $this->interest('Coffee');
        $hiking = $this->interest('Hiking');
        $art = $this->interest('Art');
        $this->personWith([$coffee, $hiking]);
        $this->personWith([$coffee, $art]);
        $this->personWith([$coffee]);
        $this->personWith([$hiking]);

        $response = $this->getJson('/api/v1/explore/interests')->assertOk();

        // Coffee 3, Hiking 2, Art 1.
        $response->assertJsonPath('interests.0.name', 'Coffee')
            ->assertJsonPath('interests.0.member_count', 3)
            ->assertJsonPath('interests.1.name', 'Hiking')
            ->assertJsonPath('interests.1.member_count', 2)
            ->assertJsonPath('interests.2.name', 'Art')
            ->assertJsonPath('interests.2.member_count', 1)
            ->assertJsonStructure(['interests' => [['id', 'name', 'category', 'member_count', 'is_yours']]]);
    }

    public function test_equal_counts_fall_back_to_alphabetical(): void
    {
        $this->viewer();
        $zen = $this->interest('Zen');
        $art = $this->interest('Art');
        $this->personWith([$zen]);
        $this->personWith([$art]);

        $this->getJson('/api/v1/explore/interests')
            ->assertJsonPath('interests.0.name', 'Art')
            ->assertJsonPath('interests.1.name', 'Zen');
    }

    public function test_an_interest_nobody_eligible_shares_is_left_out(): void
    {
        $this->viewer();
        $coffee = $this->interest('Coffee');
        $this->interest('Unused');
        $this->personWith([$coffee]);

        $this->getJson('/api/v1/explore/interests')
            ->assertJsonCount(1, 'interests')
            ->assertJsonPath('interests.0.name', 'Coffee');
    }

    public function test_counts_only_include_people_the_feed_would_show(): void
    {
        $viewer = $this->viewer(maxDistanceKm: 50);
        $coffee = $this->interest('Coffee');

        $this->personWith([$coffee], 'Visible');
        $this->personWith([$coffee], 'Wrong gender', gender: 'man');
        $this->personWith([$coffee], 'Too old', age: 60);
        $this->personWith([$coffee], 'Too far', latOffset: 3.0); // ~333 km
        $swiped = $this->personWith([$coffee], 'Swiped');
        $blocked = $this->personWith([$coffee], 'Blocked');
        $blockedMe = $this->personWith([$coffee], 'BlockedMe');
        $suspended = $this->personWith([$coffee], 'Suspended');
        $suspended->forceFill(['status' => UserStatus::Suspended])->save();
        Swipe::factory()->create(['actor_id' => $viewer->id, 'target_id' => $swiped->id, 'direction' => SwipeDirection::Left]);
        Block::factory()->create(['blocker_id' => $viewer->id, 'blocked_id' => $blocked->id]);
        Block::factory()->create(['blocker_id' => $blockedMe->id, 'blocked_id' => $viewer->id]);

        $this->getJson('/api/v1/explore/interests')
            ->assertJsonPath('interests.0.member_count', 1);

        $this->getJson("/api/v1/explore/interests/{$coffee->id}/people")
            ->assertJsonPath('total', 1)
            ->assertJsonCount(1, 'people')
            ->assertJsonPath('people.0.display_name', 'Visible');
    }

    public function test_the_viewer_is_never_counted(): void
    {
        $viewer = $this->viewer();
        $coffee = $this->interest('Coffee');
        $viewer->interests()->attach($coffee->id);

        $this->getJson('/api/v1/explore/interests')->assertJsonCount(0, 'interests');
    }

    public function test_is_yours_marks_the_viewers_own_interests(): void
    {
        $viewer = $this->viewer();
        $coffee = $this->interest('Coffee');
        $hiking = $this->interest('Hiking');
        $viewer->interests()->attach($coffee->id);
        $this->personWith([$coffee, $hiking]);

        $response = $this->getJson('/api/v1/explore/interests')->assertOk();

        $byName = collect($response->json('interests'))->keyBy('name');
        $this->assertTrue($byName['Coffee']['is_yours']);
        $this->assertFalse($byName['Hiking']['is_yours']);
    }

    public function test_people_lists_only_those_with_the_interest_annotated_for_the_viewer(): void
    {
        $viewer = $this->viewer();
        $coffee = $this->interest('Coffee');
        $hiking = $this->interest('Hiking');
        $viewer->interests()->attach($coffee->id);
        $this->personWith([$coffee, $hiking], 'Both');
        $this->personWith([$hiking], 'HikingOnly');

        $response = $this->getJson("/api/v1/explore/interests/{$coffee->id}/people")->assertOk();

        $response->assertJsonPath('interest.name', 'Coffee')
            ->assertJsonPath('total', 1)
            ->assertJsonCount(1, 'people')
            ->assertJsonPath('people.0.display_name', 'Both')
            ->assertJsonPath('people.0.shared_interests', ['Coffee'])
            ->assertJsonCount(2, 'people.0.interests')
            ->assertJsonStructure(['people' => [['id', 'age', 'distance_km', 'photos', 'prompts']]]);
    }

    public function test_people_paginates(): void
    {
        $this->viewer();
        $coffee = $this->interest('Coffee');
        foreach (range(1, 3) as $i) {
            $this->personWith([$coffee], "P{$i}");
        }

        $first = $this->getJson("/api/v1/explore/interests/{$coffee->id}/people?per_page=2")->assertOk();
        $first->assertJsonCount(2, 'people')->assertJsonPath('meta.has_more', true)->assertJsonPath('total', 3);

        $second = $this->getJson("/api/v1/explore/interests/{$coffee->id}/people?per_page=2&page=2")->assertOk();
        $second->assertJsonCount(1, 'people')->assertJsonPath('meta.has_more', false);
    }

    public function test_an_unknown_interest_is_a_404(): void
    {
        $this->viewer();

        $this->getJson('/api/v1/explore/interests/999999/people')->assertNotFound();
    }

    public function test_it_never_serialises_raw_coordinates(): void
    {
        $this->viewer();
        $coffee = $this->interest('Coffee');
        $this->personWith([$coffee]);

        $body = $this->getJson("/api/v1/explore/interests/{$coffee->id}/people")->assertOk()->getContent();

        $this->assertStringNotContainsString('latitude', $body);
        $this->assertStringNotContainsString('longitude', $body);
    }

    public function test_a_person_listed_here_can_be_liked_and_then_disappears(): void
    {
        $this->viewer();
        $coffee = $this->interest('Coffee');
        $person = $this->personWith([$coffee], 'Match candidate');

        $this->postJson('/api/v1/swipes', ['target_id' => $person->id, 'direction' => 'right'])->assertCreated();

        // Answered, so the feed's own exclusion drops them from Explore too.
        $this->getJson("/api/v1/explore/interests/{$coffee->id}/people")->assertJsonPath('total', 0);
        $this->getJson('/api/v1/explore/interests')->assertJsonCount(0, 'interests');
    }
}
