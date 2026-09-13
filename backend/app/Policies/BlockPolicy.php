<?php

namespace App\Policies;

use App\Models\User;

class BlockPolicy
{
    public function create(User $actor, User $target): bool
    {
        return $actor->id !== $target->id;
    }
}
