<?php

namespace Tests\Feature\Swipe;

use App\Models\Block;
use App\Models\Notification;
use App\Models\Swipe;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SwipeTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_swipe(): void
    {
        $target = User::factory()->create();

        $this->postJson('/api/v1/swipes', ['target_id' => $target->id, 'direction' => 'right'])
            ->assertUnauthorized();
    }

    public function test_a_left_swipe_records_a_pass_with_no_match(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();

        $response = $this->postJson('/api/v1/swipes', ['target_id' => $target->id, 'direction' => 'left']);

        $response->assertCreated()->assertJson(['matched' => false, 'match_id' => null]);
        $this->assertDatabaseHas('swipes', ['actor_id' => $actor->id, 'target_id' => $target->id, 'direction' => 'left']);
        $this->assertDatabaseCount('likes', 0);
    }

    public function test_a_right_swipe_with_no_reciprocal_records_a_like_but_no_match(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();

        $response = $this->postJson('/api/v1/swipes', ['target_id' => $target->id, 'direction' => 'right']);

        $response->assertCreated()->assertJson(['matched' => false, 'match_id' => null]);
        $this->assertDatabaseHas('likes', ['user_id' => $actor->id, 'liked_user_id' => $target->id, 'is_super' => 0]);
        $this->assertDatabaseCount('matches', 0);
    }

    public function test_mutual_right_swipes_create_a_match(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        Swipe::factory()->create(['actor_id' => $userB->id, 'target_id' => $userA->id, 'direction' => 'right']);

        Sanctum::actingAs($userA);
        $response = $this->postJson('/api/v1/swipes', ['target_id' => $userB->id, 'direction' => 'right']);

        $response->assertCreated();
        $response->assertJson(['matched' => true]);
        $matchId = $response->json('match_id');
        $this->assertNotNull($matchId);

        $this->assertDatabaseHas('matches', [
            'id' => $matchId,
            'user_one_id' => min($userA->id, $userB->id),
            'user_two_id' => max($userA->id, $userB->id),
        ]);
    }

    public function test_a_right_swipe_with_no_reciprocal_notifies_the_target(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();

        $this->postJson('/api/v1/swipes', ['target_id' => $target->id, 'direction' => 'right'])->assertCreated();

        $this->assertDatabaseHas('notifications', ['user_id' => $target->id, 'type' => 'like']);
        $this->assertDatabaseMissing('notifications', ['user_id' => $actor->id]);
        // The liker's identity must never leak through this notification —
        // "who liked me" is a separate premium-gated feature (docs/02).
        $payload = Notification::query()->where('user_id', $target->id)->first()->payload;
        $this->assertSame([], $payload);
    }

    public function test_mutual_right_swipes_notify_both_participants_of_the_match_only(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        Swipe::factory()->create(['actor_id' => $userB->id, 'target_id' => $userA->id, 'direction' => 'right']);

        Sanctum::actingAs($userA);
        $this->postJson('/api/v1/swipes', ['target_id' => $userB->id, 'direction' => 'right'])->assertCreated();

        $this->assertDatabaseHas('notifications', ['user_id' => $userA->id, 'type' => 'new_match']);
        $this->assertDatabaseHas('notifications', ['user_id' => $userB->id, 'type' => 'new_match']);
        // Reciprocating shouldn't also fire a separate "like" notification —
        // it resolved straight into a match instead.
        $this->assertDatabaseMissing('notifications', ['user_id' => $userB->id, 'type' => 'like']);
        $this->assertDatabaseCount('notifications', 2);
    }

    public function test_a_super_swipe_can_also_trigger_a_match(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        Swipe::factory()->create(['actor_id' => $userB->id, 'target_id' => $userA->id, 'direction' => 'super']);

        Sanctum::actingAs($userA);
        $this->postJson('/api/v1/swipes', ['target_id' => $userB->id, 'direction' => 'right'])
            ->assertCreated()->assertJson(['matched' => true]);
    }

    public function test_a_user_cannot_swipe_on_themselves(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $this->postJson('/api/v1/swipes', ['target_id' => $user->id, 'direction' => 'right'])
            ->assertForbidden();
    }

    public function test_a_user_cannot_swipe_the_same_target_twice(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();
        Swipe::factory()->create(['actor_id' => $actor->id, 'target_id' => $target->id, 'direction' => 'left']);

        $this->postJson('/api/v1/swipes', ['target_id' => $target->id, 'direction' => 'right'])
            ->assertStatus(422)->assertJsonPath('error.code', 'already_swiped');
    }

    public function test_a_user_cannot_swipe_someone_they_blocked(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();
        Block::factory()->create(['blocker_id' => $actor->id, 'blocked_id' => $target->id]);

        $this->postJson('/api/v1/swipes', ['target_id' => $target->id, 'direction' => 'right'])
            ->assertForbidden();
    }

    public function test_a_user_cannot_swipe_someone_who_blocked_them(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();
        Block::factory()->create(['blocker_id' => $target->id, 'blocked_id' => $actor->id]);

        $this->postJson('/api/v1/swipes', ['target_id' => $target->id, 'direction' => 'right'])
            ->assertForbidden();
    }

    public function test_it_rejects_a_nonexistent_target(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/swipes', ['target_id' => 999999, 'direction' => 'right'])
            ->assertStatus(422)->assertJsonValidationErrors('target_id');
    }

    public function test_it_rejects_an_invalid_direction(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $target = User::factory()->create();

        $this->postJson('/api/v1/swipes', ['target_id' => $target->id, 'direction' => 'sideways'])
            ->assertStatus(422)->assertJsonValidationErrors('direction');
    }
}
