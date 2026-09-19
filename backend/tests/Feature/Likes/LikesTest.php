<?php

namespace Tests\Feature\Likes;

use App\Enums\SwipeDirection;
use App\Enums\UserStatus;
use App\Models\Block;
use App\Models\Interest;
use App\Models\Like;
use App\Models\Profile;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\Swipe;
use App\Models\User;
use App\Models\UserLocation;
use App\Models\UserMatch;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * `GET /likes/received` (premium "who liked me", docs/07 §3.4) and
 * `GET /likes/sent`. The security property under test above all: a free user
 * gets a *count*, never an identity.
 */
class LikesTest extends TestCase
{
    use RefreshDatabase;

    private function person(string $name = 'Someone', ?float $lat = 3.139, ?float $lon = 101.687): User
    {
        $user = User::factory()->create();
        $profile = Profile::factory()->for($user)->create(['display_name' => $name]);
        $profile->photos()->create([
            'storage_path' => 'photos/x/'.$user->id.'.jpg',
            'sort_order' => 0,
            'moderation_status' => 'approved',
        ]);
        if ($lat !== null) {
            UserLocation::factory()->for($user)->at($lat, $lon)->create();
        }

        return $user;
    }

    private function subscriber(): User
    {
        $user = $this->person('Viewer');
        Subscription::factory()->for($user)->for(SubscriptionPlan::factory()->create(), 'plan')->create();

        return $user;
    }

    private function likes(User $from, User $to): Like
    {
        return Like::factory()->create(['user_id' => $from->id, 'liked_user_id' => $to->id]);
    }

    public function test_a_guest_cannot_view_either_list(): void
    {
        $this->getJson('/api/v1/likes/received')->assertUnauthorized();
        $this->getJson('/api/v1/likes/sent')->assertUnauthorized();
    }

    public function test_a_free_user_gets_the_count_and_no_identities(): void
    {
        $viewer = $this->person('Free viewer');
        $liker = $this->person('Secret Admirer');
        $this->likes($liker, $viewer);
        $this->likes($this->person(), $viewer);
        Sanctum::actingAs($viewer);

        $response = $this->getJson('/api/v1/likes/received')->assertOk();

        $response->assertJson(['locked' => true, 'total' => 2, 'likes' => []]);
        // Nothing that could identify a liker is anywhere in the body.
        $this->assertStringNotContainsString('Secret Admirer', $response->getContent());
        $this->assertStringNotContainsString('display_name', $response->getContent());
        $this->assertStringNotContainsString('photos', $response->getContent());
    }

    public function test_a_subscriber_sees_who_liked_them_newest_first(): void
    {
        $viewer = $this->subscriber();
        $older = $this->person('Older');
        $newer = $this->person('Newer');
        $this->likes($older, $viewer)->forceFill(['created_at' => now()->subDay()])->save();
        $this->likes($newer, $viewer);
        Sanctum::actingAs($viewer);

        $response = $this->getJson('/api/v1/likes/received')->assertOk();

        $response->assertJsonPath('locked', false)
            ->assertJsonPath('total', 2)
            ->assertJsonPath('likes.0.display_name', 'Newer')
            ->assertJsonPath('likes.1.display_name', 'Older')
            ->assertJsonStructure(['likes' => [['id', 'display_name', 'age', 'distance_km', 'photos', 'interests', 'prompts', 'liked_at']]]);
    }

    public function test_it_never_serialises_raw_coordinates(): void
    {
        $viewer = $this->subscriber();
        $this->likes($this->person('Near', 3.1391, 101.6871), $viewer);
        Sanctum::actingAs($viewer);

        $body = $this->getJson('/api/v1/likes/received')->assertOk()->getContent();

        $this->assertStringNotContainsString('latitude', $body);
        $this->assertStringNotContainsString('longitude', $body);
        $this->assertStringNotContainsString('3.1391', $body);
    }

    public function test_received_drops_people_who_are_no_longer_pending_or_visible(): void
    {
        $viewer = $this->subscriber();
        $kept = $this->person('Kept');
        $answered = $this->person('Answered');
        $matched = $this->person('Matched');
        $blocked = $this->person('Blocked');
        $blockedMe = $this->person('BlockedMe');
        $suspended = $this->person('Suspended');
        $suspended->forceFill(['status' => UserStatus::Suspended])->save();

        foreach ([$kept, $answered, $matched, $blocked, $blockedMe, $suspended] as $liker) {
            $this->likes($liker, $viewer);
        }
        Swipe::factory()->create(['actor_id' => $viewer->id, 'target_id' => $answered->id, 'direction' => SwipeDirection::Left]);
        UserMatch::factory()->between($viewer, $matched)->create();
        Block::factory()->create(['blocker_id' => $viewer->id, 'blocked_id' => $blocked->id]);
        Block::factory()->create(['blocker_id' => $blockedMe->id, 'blocked_id' => $viewer->id]);
        Sanctum::actingAs($viewer);

        $response = $this->getJson('/api/v1/likes/received')->assertOk();

        $response->assertJsonPath('total', 1)->assertJsonCount(1, 'likes')->assertJsonPath('likes.0.display_name', 'Kept');
    }

    public function test_the_free_count_applies_the_same_exclusions(): void
    {
        $viewer = $this->person('Free');
        $this->likes($this->person(), $viewer);
        $blocked = $this->person();
        $this->likes($blocked, $viewer);
        Block::factory()->create(['blocker_id' => $viewer->id, 'blocked_id' => $blocked->id]);
        Sanctum::actingAs($viewer);

        $this->getJson('/api/v1/likes/received')->assertJson(['locked' => true, 'total' => 1]);
    }

    public function test_received_does_not_include_likes_sent_to_other_people(): void
    {
        $viewer = $this->subscriber();
        $this->likes($this->person(), $this->person());
        Sanctum::actingAs($viewer);

        $this->getJson('/api/v1/likes/received')->assertJson(['total' => 0, 'likes' => []]);
    }

    public function test_received_paginates(): void
    {
        $viewer = $this->subscriber();
        foreach (range(1, 3) as $i) {
            $this->likes($this->person("P{$i}"), $viewer);
        }
        Sanctum::actingAs($viewer);

        $first = $this->getJson('/api/v1/likes/received?per_page=2')->assertOk();
        $first->assertJsonCount(2, 'likes')->assertJsonPath('meta.has_more', true)->assertJsonPath('total', 3);

        $second = $this->getJson('/api/v1/likes/received?per_page=2&page=2')->assertOk();
        $second->assertJsonCount(1, 'likes')->assertJsonPath('meta.has_more', false);
    }

    public function test_a_liker_without_a_location_still_appears_with_no_distance(): void
    {
        $viewer = $this->subscriber();
        $this->likes($this->person('Nowhere', null), $viewer);
        Sanctum::actingAs($viewer);

        $this->getJson('/api/v1/likes/received')
            ->assertOk()
            ->assertJsonPath('likes.0.display_name', 'Nowhere')
            ->assertJsonPath('likes.0.distance_km', null);
    }

    public function test_shared_interests_are_annotated_for_the_viewer(): void
    {
        $viewer = $this->subscriber();
        $liker = $this->person('Sharer');
        $coffee = Interest::factory()->create(['name' => 'Coffee']);
        $hiking = Interest::factory()->create(['name' => 'Hiking']);
        $viewer->interests()->attach([$coffee->id]);
        $liker->interests()->attach([$coffee->id, $hiking->id]);
        $this->likes($liker, $viewer);
        Sanctum::actingAs($viewer);

        $this->getJson('/api/v1/likes/received')
            ->assertJsonPath('likes.0.shared_interests', ['Coffee'])
            ->assertJsonPath('likes.0.shared_interests_count', 1)
            ->assertJsonCount(2, 'likes.0.interests');
    }

    public function test_sent_lists_pending_likes_and_is_free(): void
    {
        $viewer = $this->person('Free');
        $pending = $this->person('Pending');
        $matched = $this->person('Matched');
        $unmatched = $this->person('Unmatched');
        $blocked = $this->person('Blocked');
        foreach ([$pending, $matched, $unmatched, $blocked] as $target) {
            $this->likes($viewer, $target);
        }
        UserMatch::factory()->between($viewer, $matched)->create();
        UserMatch::factory()->between($viewer, $unmatched)->unmatched()->create();
        Block::factory()->create(['blocker_id' => $blocked->id, 'blocked_id' => $viewer->id]);
        Sanctum::actingAs($viewer);

        $this->getJson('/api/v1/likes/sent')
            ->assertOk()
            ->assertJsonPath('total', 1)
            ->assertJsonCount(1, 'likes')
            ->assertJsonPath('likes.0.display_name', 'Pending')
            ->assertJsonPath('likes.0.id', $pending->id);
    }

    public function test_a_swipe_creates_a_like_that_then_shows_up_here(): void
    {
        $viewer = $this->subscriber();
        $admirer = $this->person('Admirer');
        Sanctum::actingAs($admirer);
        $this->postJson('/api/v1/swipes', ['target_id' => $viewer->id, 'direction' => 'right'])->assertCreated();

        Sanctum::actingAs($viewer);
        $this->getJson('/api/v1/likes/received')->assertJsonPath('likes.0.id', $admirer->id);
        // Liking them back answers it: it leaves "received".
        $this->postJson('/api/v1/swipes', ['target_id' => $admirer->id, 'direction' => 'right'])
            ->assertCreated()->assertJson(['matched' => true]);
        $this->getJson('/api/v1/likes/received')->assertJson(['total' => 0]);
    }
}
