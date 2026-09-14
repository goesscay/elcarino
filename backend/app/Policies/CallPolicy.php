<?php

namespace App\Policies;

use App\Models\Call;
use App\Models\User;

/**
 * docs/06-security-architecture.md §3.4: "Call token cannot be obtained by
 * a non-subscriber or a non-participant." The subscriber/active-match
 * checks live in CallController (same pattern as ChatController's
 * unmatched-messaging check — the specific `error.code` envelope those
 * need doesn't come from a Policy's plain 403), not here; this policy is
 * just "is this user one of the call's two participants", used for
 * answer/decline/end.
 */
class CallPolicy
{
    public function view(User $user, Call $call): bool
    {
        return $call->isParticipant($user);
    }

    public function answer(User $user, Call $call): bool
    {
        return $call->callee_id === $user->id;
    }

    public function decline(User $user, Call $call): bool
    {
        return $call->callee_id === $user->id;
    }

    public function end(User $user, Call $call): bool
    {
        return $call->isParticipant($user);
    }
}
