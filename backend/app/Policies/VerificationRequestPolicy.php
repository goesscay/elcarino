<?php

namespace App\Policies;

use App\Models\User;
use App\Models\VerificationRequest;

/**
 * docs/06 §3.3: "Moderators: reports queue + verification review + user
 * suspend only" — so admins *and* moderators may work the verification queue.
 * Nothing else is granted: no create (requests come only from the mobile API),
 * no edit, no delete (the row is the audit trail).
 */
class VerificationRequestPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->isAdmin() || $user->isModerator();
    }

    public function view(User $user, VerificationRequest $request): bool
    {
        return $this->viewAny($user);
    }
}
