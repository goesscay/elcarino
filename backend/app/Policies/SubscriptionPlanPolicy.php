<?php

namespace App\Policies;

use App\Models\SubscriptionPlan;
use App\Models\User;

/**
 * Phase 2 item 5. Admin-only for everything — docs/06-security-architecture.md
 * §3.3: "Moderators: ... cannot change plans." There is no mobile-facing
 * write path for `subscription_plans` at all (`GET /subscriptions/plans` is
 * read-only, unauthenticated-by-role), so this policy only ever gates the
 * Filament panel.
 */
class SubscriptionPlanPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->isAdmin();
    }

    public function view(User $user, SubscriptionPlan $plan): bool
    {
        return $user->isAdmin();
    }

    public function create(User $user): bool
    {
        return $user->isAdmin();
    }

    public function update(User $user, SubscriptionPlan $plan): bool
    {
        return $user->isAdmin();
    }

    public function delete(User $user, SubscriptionPlan $plan): bool
    {
        return $user->isAdmin();
    }
}
