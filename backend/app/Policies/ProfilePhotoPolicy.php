<?php

namespace App\Policies;

use App\Models\ProfilePhoto;
use App\Models\User;

class ProfilePhotoPolicy
{
    public function delete(User $user, ProfilePhoto $photo): bool
    {
        return $photo->profile->user_id === $user->id;
    }
}
