<?php

namespace Tests\Feature\Chat;

use App\Enums\SwipeDirection;
use App\Events\MessagesReadBroadcast;
use App\Events\NewMessageBroadcast;
use App\Models\Block;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\Profile;
use App\Models\Swipe;
use App\Models\User;
use App\Models\UserMatch;
use App\Services\Matching\SwipeService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ChatTest extends TestCase
{
    use RefreshDatabase;

    private function matchedPair(): array
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

        return [$userA, $userB, $conversation, $match];
    }

    public function test_a_guest_cannot_use_any_chat_endpoint(): void
    {
        [, , $conversation] = $this->matchedPair();

        $this->getJson('/api/v1/chat/conversations')->assertUnauthorized();
        $this->getJson("/api/v1/chat/conversations/{$conversation->id}/messages")->assertUnauthorized();
        $this->postJson("/api/v1/chat/conversations/{$conversation->id}/messages", ['body' => 'hi'])
            ->assertUnauthorized();
        $this->putJson("/api/v1/chat/conversations/{$conversation->id}/read")->assertUnauthorized();
    }

    public function test_matching_creates_a_conversation_automatically(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        Swipe::factory()->create(['actor_id' => $userB->id, 'target_id' => $userA->id, 'direction' => 'right']);

        app(SwipeService::class)->recordSwipe($userA, $userB, SwipeDirection::Right);

        $this->assertDatabaseHas('conversations', [
            'user_one_id' => min($userA->id, $userB->id),
            'user_two_id' => max($userA->id, $userB->id),
        ]);
    }

    public function test_a_participant_sees_the_conversation_in_their_inbox(): void
    {
        [$userA, , $conversation, $match] = $this->matchedPair();

        Sanctum::actingAs($userA);
        $response = $this->getJson('/api/v1/chat/conversations')->assertOk();

        $response->assertJsonCount(1, 'conversations');
        $response->assertJsonPath('conversations.0.id', $conversation->id);
        // So the client can unmatch (DELETE /matches/{id}) from the inbox
        // without a second round-trip to look the match id up.
        $response->assertJsonPath('conversations.0.match_id', $match->id);
    }

    public function test_a_non_participant_does_not_see_the_conversation(): void
    {
        $this->matchedPair();
        $stranger = User::factory()->create();

        Sanctum::actingAs($stranger);
        $this->getJson('/api/v1/chat/conversations')->assertOk()->assertJsonCount(0, 'conversations');
    }

    public function test_a_blocked_conversation_is_excluded_from_the_inbox_in_either_direction(): void
    {
        [$userA, $userB] = $this->matchedPair();
        Block::factory()->create(['blocker_id' => $userA->id, 'blocked_id' => $userB->id]);

        Sanctum::actingAs($userA);
        $this->getJson('/api/v1/chat/conversations')->assertOk()->assertJsonCount(0, 'conversations');

        // Not just from the blocker's side — the blocked party shouldn't
        // see it either, same as ConversationPolicy::view already enforces
        // for opening it directly.
        Sanctum::actingAs($userB);
        $this->getJson('/api/v1/chat/conversations')->assertOk()->assertJsonCount(0, 'conversations');
    }

    public function test_a_participant_can_send_a_text_message(): void
    {
        Event::fake([NewMessageBroadcast::class]);
        [$userA, $userB, $conversation] = $this->matchedPair();

        Sanctum::actingAs($userA);
        $response = $this->postJson("/api/v1/chat/conversations/{$conversation->id}/messages", [
            'body' => 'Hey there!',
        ]);

        $response->assertCreated()->assertJsonPath('message.body', 'Hey there!');
        $response->assertJsonPath('message.sender_id', $userA->id);
        $this->assertDatabaseHas('messages', [
            'conversation_id' => $conversation->id,
            'sender_id' => $userA->id,
            'body' => 'Hey there!',
            'type' => 'text',
        ]);
        $this->assertNotNull($conversation->fresh()->last_message_at);

        Event::assertDispatched(
            NewMessageBroadcast::class,
            fn (NewMessageBroadcast $event) => $event->message->conversation_id === $conversation->id
                && $event->message->body === 'Hey there!',
        );
        $this->assertDatabaseHas('notifications', ['user_id' => $userB->id, 'type' => 'new_message']);
        $this->assertDatabaseMissing('notifications', ['user_id' => $userA->id]);
    }

    public function test_a_non_participant_cannot_send_a_message(): void
    {
        [, , $conversation] = $this->matchedPair();
        $stranger = User::factory()->create();

        Sanctum::actingAs($stranger);
        $this->postJson("/api/v1/chat/conversations/{$conversation->id}/messages", ['body' => 'hi'])
            ->assertForbidden();
    }

    public function test_sending_requires_a_non_empty_body(): void
    {
        [$userA, , $conversation] = $this->matchedPair();

        Sanctum::actingAs($userA);
        $this->postJson("/api/v1/chat/conversations/{$conversation->id}/messages", ['body' => ''])
            ->assertStatus(422)->assertJsonValidationErrors('body');
    }

    public function test_a_blocked_participant_cannot_send_or_view(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();
        Block::factory()->create(['blocker_id' => $userB->id, 'blocked_id' => $userA->id]);

        Sanctum::actingAs($userA);
        $this->getJson("/api/v1/chat/conversations/{$conversation->id}/messages")->assertForbidden();
        $this->postJson("/api/v1/chat/conversations/{$conversation->id}/messages", ['body' => 'hi'])
            ->assertForbidden();
    }

    /**
     * docs/06-security-architecture.md §9: a suspended/banned account's
     * "existing conversations [are] frozen (read-only)" — Phase 1 item 11.
     * The freeze applies to *either* participant sending, not just the
     * suspended one, and viewing/reading stays allowed.
     */
    public function test_a_frozen_conversation_is_read_only_for_both_participants(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();
        $userB->forceFill(['status' => 'suspended'])->save();

        Sanctum::actingAs($userA);
        $this->getJson("/api/v1/chat/conversations/{$conversation->id}/messages")->assertOk();
        $this->postJson("/api/v1/chat/conversations/{$conversation->id}/messages", ['body' => 'hi'])
            ->assertForbidden();

        Sanctum::actingAs($userB);
        $this->getJson("/api/v1/chat/conversations/{$conversation->id}/messages")->assertOk();
        $this->postJson("/api/v1/chat/conversations/{$conversation->id}/messages", ['body' => 'hi'])
            ->assertForbidden();
    }

    public function test_sending_to_an_unmatched_conversation_requires_a_subscription(): void
    {
        [$userA, , $conversation, $match] = $this->matchedPair();
        $match->forceFill(['unmatched_at' => now(), 'unmatched_by' => $userA->id])->save();

        Sanctum::actingAs($userA);
        $this->postJson("/api/v1/chat/conversations/{$conversation->id}/messages", ['body' => 'still there?'])
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'subscription_required');
    }

    public function test_messages_are_paginated_newest_first(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();
        $first = Message::factory()->for($conversation)->create(['sender_id' => $userA->id, 'body' => 'first']);
        $second = Message::factory()->for($conversation)->create(['sender_id' => $userB->id, 'body' => 'second']);
        // Eloquent's own timestamp management always stamps created_at with
        // "now" on insert regardless of what's passed to create(), which
        // would make these two ties in a fast test run — a raw update
        // bypasses that so the ordering assertion below is actually
        // exercising the query's ORDER BY, not incidental insert order.
        DB::table('messages')->where('id', $first->id)->update(['created_at' => now()->subMinutes(2)]);
        DB::table('messages')->where('id', $second->id)->update(['created_at' => now()->subMinute()]);

        Sanctum::actingAs($userA);
        $response = $this->getJson("/api/v1/chat/conversations/{$conversation->id}/messages")->assertOk();

        $response->assertJsonPath('messages.0.body', 'second');
        $response->assertJsonPath('messages.1.body', 'first');
    }

    public function test_marking_read_only_affects_the_other_participants_messages(): void
    {
        Event::fake([MessagesReadBroadcast::class]);
        [$userA, $userB, $conversation] = $this->matchedPair();
        $fromA = Message::factory()->for($conversation)->create(['sender_id' => $userA->id]);
        $fromB = Message::factory()->for($conversation)->create(['sender_id' => $userB->id]);

        Sanctum::actingAs($userA);
        $this->putJson("/api/v1/chat/conversations/{$conversation->id}/read")->assertOk();

        $this->assertNull($fromA->fresh()->read_at, "the viewer's own message shouldn't be marked read by them");
        $this->assertNotNull($fromB->fresh()->read_at);

        Event::assertDispatched(
            MessagesReadBroadcast::class,
            fn (MessagesReadBroadcast $event) => $event->conversationId === $conversation->id
                && $event->readByUserId === $userA->id,
        );
    }

    public function test_inbox_includes_a_last_message_preview(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();

        Sanctum::actingAs($userA);
        $noMessagesYet = $this->getJson('/api/v1/chat/conversations')->assertOk();
        $noMessagesYet->assertJsonPath('conversations.0.last_message_preview', null);

        Message::factory()->for($conversation)->create(['sender_id' => $userB->id, 'body' => 'first']);
        $latest = Message::factory()->for($conversation)->create(['sender_id' => $userA->id, 'body' => 'latest one']);
        DB::table('messages')->where('id', $latest->id)->update(['created_at' => now()->addMinute()]);

        $withMessages = $this->getJson('/api/v1/chat/conversations')->assertOk();
        $withMessages->assertJsonPath('conversations.0.last_message_preview', 'latest one');
    }

    public function test_unread_count_reflects_only_the_other_participants_unread_messages(): void
    {
        [$userA, $userB, $conversation] = $this->matchedPair();
        Message::factory()->for($conversation)->create(['sender_id' => $userB->id]);
        Message::factory()->for($conversation)->create(['sender_id' => $userB->id]);
        Message::factory()->for($conversation)->create(['sender_id' => $userA->id]); // viewer's own, never "unread" to them

        Sanctum::actingAs($userA);
        $response = $this->getJson('/api/v1/chat/conversations')->assertOk();

        $response->assertJsonPath('conversations.0.unread_count', 2);
    }
}
