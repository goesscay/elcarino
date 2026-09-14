<?php

namespace App\Policies;

use App\Enums\UserStatus;
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

    /**
     * docs/06 §9: a suspended/banned account's "existing conversations
     * [are] frozen (read-only)" — enforced here on top of `view()`'s own
     * checks, not just on the suspended user's own send button, since the
     * *other* participant must also be unable to send into a frozen
     * conversation (there'd otherwise be no reply for the suspended party
     * to ever read, but the rule is about the conversation being frozen,
     * not about who's allowed to type).
     */
    public function sendMessage(User $user, Conversation $conversation): bool
    {
        if (! $this->view($user, $conversation)) {
            return false;
        }

        return $conversation->userOne->status === UserStatus::Active
            && $conversation->userTwo->status === UserStatus::Active;
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
