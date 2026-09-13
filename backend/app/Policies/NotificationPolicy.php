<?php

namespace App\Policies;

use App\Models\Notification;
use App\Models\User;

class NotificationPolicy
{
    public function update(User $user, Notification $notification): bool
    {
        return $notification->user_id === $user->id;
    }
}
