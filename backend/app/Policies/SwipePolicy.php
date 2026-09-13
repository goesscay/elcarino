<?php

namespace App\Policies;

use App\Models\Block;
use App\Models\User;

/**
 * docs/06-security-architecture.md §3.1 names SwipePolicy explicitly as one
 * of the per-resource policies expected in this app.
 */
class SwipePolicy
{
    public function create(User $actor, User $target): bool
    {
        if ($actor->id === $target->id) {
            return false;
        }

        $blockedEitherDirection = Block::query()
            ->where(fn ($q) => $q->where('blocker_id', $actor->id)->where('blocked_id', $target->id))
            ->orWhere(fn ($q) => $q->where('blocker_id', $target->id)->where('blocked_id', $actor->id))
            ->exists();

        return ! $blockedEitherDirection;
    }
}
