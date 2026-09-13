<?php

namespace App\Policies;

use App\Models\User;
use App\Models\UserMatch;

class UserMatchPolicy
{
    public function view(User $user, UserMatch $match): bool
    {
        return $match->isParticipant($user);
    }

    public function delete(User $user, UserMatch $match): bool
    {
        return $match->isParticipant($user) && $match->isActive();
    }
}
