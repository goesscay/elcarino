<?php

namespace App\Policies;

use App\Models\Subscription;
use App\Models\User;

/**
 * Shared between the mobile API (a user cancelling their own subscription)
 * and the Filament admin panel (Phase 2 item 5) — `viewAny`/`view` only
 * matter to the panel today (nothing on the mobile side calls
 * Gate::authorize('view'|'viewAny', ...) against this model), so they're
 * admin-only without touching the mobile-facing `cancel` contract beyond
 * widening it to also allow an admin cancelling *someone else's*
 * subscription from the panel.
 */
class SubscriptionPolicy
{
    /**
     * docs/06-security-architecture.md §3.3: "Moderators: ... cannot touch
     * subscription/payment data" — moderators don't get this resource at
     * all, admins do.
     */
    public function viewAny(User $user): bool
    {
        return $user->isAdmin();
    }

    public function view(User $user, Subscription $subscription): bool
    {
        return $user->isAdmin();
    }

    public function cancel(User $user, Subscription $subscription): bool
    {
        return $user->isAdmin() || $subscription->user_id === $user->id;
    }
}
