<?php

namespace Tests\Feature\Safety;

use App\Models\Block;
use App\Models\Profile;
use App\Models\User;
use App\Models\UserMatch;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BlockTest extends TestCase
{
    use RefreshDatabase;

    private function userWithProfile(): User
    {
        $user = User::factory()->create();
        $profile = Profile::factory()->for($user)->create();
        $profile->photos()->create(['storage_path' => 'photos/x/'.$user->id.'.jpg', 'sort_order' => 0]);

        return $user;
    }

    public function test_a_guest_cannot_use_any_block_endpoint(): void
    {
        $target = User::factory()->create();

        $this->getJson('/api/v1/safety/blocks')->assertUnauthorized();
        $this->postJson('/api/v1/safety/block', ['user_id' => $target->id])->assertUnauthorized();
        $this->deleteJson("/api/v1/safety/block/{$target->id}")->assertUnauthorized();
    }

    public function test_a_user_can_block_another_user(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();

        $this->postJson('/api/v1/safety/block', ['user_id' => $target->id])->assertCreated();

        $this->assertDatabaseHas('blocks', ['blocker_id' => $actor->id, 'blocked_id' => $target->id]);
    }

    public function test_blocking_is_idempotent(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();

        $this->postJson('/api/v1/safety/block', ['user_id' => $target->id])->assertCreated();
        $this->postJson('/api/v1/safety/block', ['user_id' => $target->id])->assertCreated();

        $this->assertDatabaseCount('blocks', 1);
    }

    public function test_a_user_cannot_block_themselves(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $this->postJson('/api/v1/safety/block', ['user_id' => $user->id])->assertForbidden();
    }

    public function test_blocking_requires_an_existing_user(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/safety/block', ['user_id' => 999999])
            ->assertStatus(422)->assertJsonValidationErrors('user_id');
    }

    public function test_blocking_also_unmatches_an_active_match(): void
    {
        $actor = $this->userWithProfile();
        $target = $this->userWithProfile();
        $match = UserMatch::factory()->between($actor, $target)->create();

        Sanctum::actingAs($actor);
        $this->postJson('/api/v1/safety/block', ['user_id' => $target->id])->assertCreated();

        $match->refresh();
        $this->assertNotNull($match->unmatched_at);
        $this->assertSame($actor->id, $match->unmatched_by);
    }

    public function test_blocking_with_no_active_match_does_not_error(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();

        $this->postJson('/api/v1/safety/block', ['user_id' => $target->id])->assertCreated();
    }

    public function test_a_blocked_user_cannot_be_swiped_on(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();
        $this->postJson('/api/v1/safety/block', ['user_id' => $target->id])->assertCreated();

        $this->postJson('/api/v1/swipes', ['target_id' => $target->id, 'direction' => 'right'])
            ->assertForbidden();
    }

    public function test_a_user_sees_their_blocked_users_with_display_name_and_photo(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = $this->userWithProfile();
        Block::factory()->create(['blocker_id' => $actor->id, 'blocked_id' => $target->id]);

        $response = $this->getJson('/api/v1/safety/blocks')->assertOk();

        $response->assertJsonCount(1, 'blocked_users');
        $response->assertJsonPath('blocked_users.0.id', $target->id);
        $response->assertJsonPath(
            'blocked_users.0.display_name',
            $target->profile->display_name,
        );
        $this->assertNotNull($response->json('blocked_users.0.photo.url'));
    }

    public function test_the_blocked_users_list_is_null_safe_for_a_profile_less_target(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create(); // no Profile at all

        Block::factory()->create(['blocker_id' => $actor->id, 'blocked_id' => $target->id]);

        $response = $this->getJson('/api/v1/safety/blocks')->assertOk();

        $response->assertJsonPath('blocked_users.0.display_name', null);
        $response->assertJsonPath('blocked_users.0.photo', null);
    }

    public function test_a_user_sees_only_their_own_blocked_users(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        Block::factory()->create(['blocker_id' => $actor->id]);
        Block::factory()->create(); // someone else's block

        $response = $this->getJson('/api/v1/safety/blocks')->assertOk();

        $response->assertJsonCount(1, 'blocked_users');
    }

    public function test_a_user_can_unblock(): void
    {
        Sanctum::actingAs($actor = User::factory()->create());
        $target = User::factory()->create();
        Block::factory()->create(['blocker_id' => $actor->id, 'blocked_id' => $target->id]);

        $this->deleteJson("/api/v1/safety/block/{$target->id}")->assertOk();

        $this->assertDatabaseMissing('blocks', ['blocker_id' => $actor->id, 'blocked_id' => $target->id]);
    }

    public function test_unblocking_someone_not_blocked_does_not_error(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $target = User::factory()->create();

        $this->deleteJson("/api/v1/safety/block/{$target->id}")->assertOk();
    }

    public function test_unblock_only_removes_the_callers_own_block(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        // B blocked A. A calling DELETE /safety/block/{B} must not be able
        // to remove B's block of A — only A's own (nonexistent) block of B.
        Block::factory()->create(['blocker_id' => $userB->id, 'blocked_id' => $userA->id]);

        Sanctum::actingAs($userA);
        $this->deleteJson("/api/v1/safety/block/{$userB->id}")->assertOk();

        $this->assertDatabaseHas('blocks', ['blocker_id' => $userB->id, 'blocked_id' => $userA->id]);
    }
}
