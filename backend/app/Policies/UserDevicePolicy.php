<?php

namespace App\Policies;

use App\Models\User;
use App\Models\UserDevice;

class UserDevicePolicy
{
    public function delete(User $user, UserDevice $device): bool
    {
        return $device->user_id === $user->id;
    }
}
