<?php

namespace App\Policies;

use App\Models\Block;
use App\Models\Conversation;
use App\Models\User;

/**
 * docs/06-security-architecture.md §3.2: "a user may read/write a
 * conversation only if they are one of its two participants and neither has
 * blocked the other."
 */
class ConversationPolicy
{
    public function view(User $user, Conversation $conversation): bool
    {
        return $conversation->isParticipant($user) && ! $this->blockedEitherDirection($conversation, $user);
    }

    public function sendMessage(User $user, Conversation $conversation): bool
    {
        return $this->view($user, $conversation);
    }

    private function blockedEitherDirection(Conversation $conversation, User $viewer): bool
    {
        $other = $conversation->otherUser($viewer);

        return Block::query()
            ->where(fn ($q) => $q->where('blocker_id', $viewer->id)->where('blocked_id', $other->id))
            ->orWhere(fn ($q) => $q->where('blocker_id', $other->id)->where('blocked_id', $viewer->id))
            ->exists();
    }
}
