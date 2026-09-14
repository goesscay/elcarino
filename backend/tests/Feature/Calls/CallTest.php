<?php

namespace Tests\Feature\Calls;

use App\Enums\CallStatus;
use App\Events\CallAnsweredBroadcast;
use App\Events\CallEndedBroadcast;
use App\Events\CallIncomingBroadcast;
use App\Models\Block;
use App\Models\Call;
use App\Models\Conversation;
use App\Models\Profile;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Models\UserMatch;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CallTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @return array{0: User, 1: User, 2: Conversation, 3: UserMatch}
     */
    private function matchedPair(bool $subscriberCaller = true): array
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        Profile::factory()->for($userA)->create();
        Profile::factory()->for($userB)->create();
        $match = UserMatch::factory()->between($userA, $userB)->create();
        $conversation = Conversation::query()->create([
            'match_id' => $match->id,
            'user_one_id' => min($userA->id, $userB->id),
            'user_two_id' => max($userA->id, $userB->id),
        ]);

        if ($subscriberCaller) {
            $plan = SubscriptionPlan::factory()->create();
            Subscription::factory()->for($userA)->for($plan, 'plan')->create();
        }

        return [$userA, $userB, $conversation, $match];
    }

    public function test_a_guest_cannot_use_any_call_endpoint(): void
    {
        [, , $conversation] = $this->matchedPair();
        $call = Call::factory()->for($conversation)->create();

        $this->postJson('/api/v1/calls/token', ['conversation_id' => $conversation->id, 'type' => 'voice'])
            ->assertUnauthorized();
        $this->postJson("/api/v1/calls/{$call->id}/answer")->assertUnauthorized();
        $this->postJson("/api/v1/calls/{$call->id}/decline")->assertUnauthorized();
        $this->postJson("/api/v1/calls/{$call->id}/end")->assertUnauthorized();
    }

    public function test_a_subscriber_with_an_active_match_can_start_a_call(): void
    {
        Event::fake([CallIncomingBroadcast::class]);
        [$userA, $userB, $conversation] = $this->matchedPair();

        Sanctum::actingAs($userA);
        $response = $this->postJson('/api/v1/calls/token', [
            'conversation_id' => $conversation->id,
            'type' => 'video',
        ]);

        $response->assertCreated();
        $response->assertJsonPath('call.type', 'video');
        $response->assertJsonPath('call.status', 'ringing');
        $response->assertJsonPath('call.caller.id', $userA->id);
        $response->assertJsonPath('call.callee.id', $userB->id);
        $this->assertNotEmpty($response->json('ice_servers'));

        $this->assertDatabaseHas('calls', [
            'conversation_id' => $conversation->id,
            'caller_id' => $userA->id,
            'callee_id' => $userB->id,
            'type' => 'video',
            'status' => 'ringing',
        ]);

        Event::assertDispatched(
            CallIncomingBroadcast::class,
            fn (CallIncomingBroadcast $event) => $event->call->conversation_id === $conversation->id,
        );
    }

    public function test_a_non_participant_cannot_start_a_call(): void
    {
        [, , $conversation] = $this->matchedPair();
        $stranger = User::factory()->create();

        Sanctum::actingAs($stranger);
        $this->postJson('/api/v1/calls/token', ['conversation_id' => $conversation->id, 'type' => 'voice'])
            ->assertForbidden();
    }

    public function test_a_non_subscriber_cannot_start_a_call(): void
    {
        [$userA, , $conversation] = $this->matchedPair(subscriberCaller: false);

        Sanctum::actingAs($userA);
        $this->postJson('/api/v1/calls/token', ['conversation_id' => $conversation->id, 'type' => 'voice'])
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'subscription_required');
    }

    /**
     * spec §13: "Match → subscriber? → yes: voice/video" — unlike
     * unmatched-messaging, a subscriber still can't call without an active
     * match; there's no "call anyone if you're a subscriber" carve-out.
     */
    public function test_a_subscriber_cannot_call_without_an_active_match(): void
    {
        [$userA, , $conversation, $match] = $this->matchedPair();
        $match->forceFill(['unmatched_at' => now(), 'unmatched_by' => $userA->id])->save();

        Sanctum::actingAs($userA);
        $this->postJson('/api/v1/calls/token', ['conversation_id' => $conversation->id, 'type' => 'voice'])
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'active_match_required');
    }

    public function test_a_blocked_conversation_cannot_be_called_into(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();
        Block::factory()->create(['blocker_id' => $userB->id, 'blocked_id' => $userA->id]);

        Sanctum::actingAs($userA);
        $this->postJson('/api/v1/calls/token', ['conversation_id' => $conversation->id, 'type' => 'voice'])
            ->assertForbidden();
    }

    public function test_the_callee_can_answer_a_ringing_call(): void
    {
        Event::fake([CallAnsweredBroadcast::class]);
        [$userA, $userB, $conversation] = $this->matchedPair();
        $call = Call::factory()->for($conversation)->create(['caller_id' => $userA->id, 'callee_id' => $userB->id]);

        Sanctum::actingAs($userB);
        $response = $this->postJson("/api/v1/calls/{$call->id}/answer");

        $response->assertOk();
        $response->assertJsonPath('call.status', 'active');
        $this->assertNotEmpty($response->json('ice_servers'));
        $this->assertSame(CallStatus::Active, $call->fresh()->status);
        $this->assertNotNull($call->fresh()->started_at);
        Event::assertDispatched(CallAnsweredBroadcast::class);
    }

    public function test_the_caller_cannot_answer_their_own_call(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();
        $call = Call::factory()->for($conversation)->create(['caller_id' => $userA->id, 'callee_id' => $userB->id]);

        Sanctum::actingAs($userA);
        $this->postJson("/api/v1/calls/{$call->id}/answer")->assertForbidden();
    }

    public function test_answering_a_non_ringing_call_is_rejected(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();
        $call = Call::factory()->for($conversation)->active()->create([
            'caller_id' => $userA->id,
            'callee_id' => $userB->id,
        ]);

        Sanctum::actingAs($userB);
        $this->postJson("/api/v1/calls/{$call->id}/answer")
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'call_not_ringing');
    }

    public function test_the_callee_can_decline_a_ringing_call(): void
    {
        Event::fake([CallEndedBroadcast::class]);
        [$userA, $userB, $conversation] = $this->matchedPair();
        $call = Call::factory()->for($conversation)->create(['caller_id' => $userA->id, 'callee_id' => $userB->id]);

        Sanctum::actingAs($userB);
        $response = $this->postJson("/api/v1/calls/{$call->id}/decline");

        $response->assertOk();
        $response->assertJsonPath('call.status', 'declined');
        $this->assertNotNull($call->fresh()->ended_at);
        $this->assertSame($userB->id, $call->fresh()->ended_by);
        Event::assertDispatched(CallEndedBroadcast::class);
    }

    public function test_the_caller_cannot_decline_the_call_they_placed(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();
        $call = Call::factory()->for($conversation)->create(['caller_id' => $userA->id, 'callee_id' => $userB->id]);

        Sanctum::actingAs($userA);
        $this->postJson("/api/v1/calls/{$call->id}/decline")->assertForbidden();
    }

    public function test_ending_an_active_call_computes_duration_and_marks_it_ended(): void
    {
        Event::fake([CallEndedBroadcast::class]);
        [$userA, $userB, $conversation] = $this->matchedPair();
        $call = Call::factory()->for($conversation)->create([
            'caller_id' => $userA->id,
            'callee_id' => $userB->id,
            'status' => CallStatus::Active,
            'started_at' => now()->subMinutes(3),
        ]);

        Sanctum::actingAs($userA);
        $response = $this->postJson("/api/v1/calls/{$call->id}/end");

        $response->assertOk();
        $response->assertJsonPath('call.status', 'ended');
        $fresh = $call->fresh();
        $this->assertSame(CallStatus::Ended, $fresh->status);
        $this->assertNotNull($fresh->duration_seconds);
        $this->assertGreaterThanOrEqual(179, $fresh->duration_seconds);
        Event::assertDispatched(CallEndedBroadcast::class);
    }

    /**
     * The caller gives up (or the client times out) before the callee ever
     * answers — a distinct, more useful analytics state than "ended".
     */
    public function test_ending_a_still_ringing_call_marks_it_missed_not_ended(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();
        $call = Call::factory()->for($conversation)->create(['caller_id' => $userA->id, 'callee_id' => $userB->id]);

        Sanctum::actingAs($userA);
        $this->postJson("/api/v1/calls/{$call->id}/end")->assertOk()
            ->assertJsonPath('call.status', 'missed');
        $this->assertNull($call->fresh()->duration_seconds);
    }

    public function test_ending_an_already_ended_call_is_idempotent(): void
    {
        Event::fake([CallEndedBroadcast::class]);
        [$userA, $userB, $conversation] = $this->matchedPair();
        $call = Call::factory()->for($conversation)->ended()->create([
            'caller_id' => $userA->id,
            'callee_id' => $userB->id,
        ]);

        Sanctum::actingAs($userB);
        $this->postJson("/api/v1/calls/{$call->id}/end")->assertOk()->assertJsonPath('call.status', 'ended');

        Event::assertNotDispatched(CallEndedBroadcast::class);
    }

    public function test_a_non_participant_cannot_end_a_call(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();
        $call = Call::factory()->for($conversation)->create(['caller_id' => $userA->id, 'callee_id' => $userB->id]);
        $stranger = User::factory()->create();

        Sanctum::actingAs($stranger);
        $this->postJson("/api/v1/calls/{$call->id}/end")->assertForbidden();
    }
}
