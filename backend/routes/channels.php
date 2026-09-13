<?php

use App\Models\Conversation;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Gate;

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

/**
 * docs/03-api-specification.md: `presence:conversation.{id}` — real-time
 * message delivery, typing indicator, online/offline status. A presence
 * channel (not private): the member list Reverb tracks *is* the "who's
 * online in this conversation" signal docs/07 §3.3's "online/last-active in
 * header" needs, and typing indicators are peer-to-peer client events over
 * this same channel — neither needs a REST endpoint of its own. Reuses
 * ConversationPolicy::view so the exact same participant-and-not-blocked
 * rule gates both the REST endpoints and the socket subscription.
 */
Broadcast::channel('conversation.{conversationId}', function (User $user, int $conversationId) {
    $conversation = Conversation::find($conversationId);

    if (! $conversation || ! Gate::forUser($user)->allows('view', $conversation)) {
        return null;
    }

    return ['id' => $user->id, 'name' => $user->profile?->display_name ?? 'Someone'];
});
