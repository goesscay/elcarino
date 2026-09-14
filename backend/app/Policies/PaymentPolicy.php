<?php

namespace App\Policies;

use App\Models\Payment;
use App\Models\User;

/**
 * Phase 2 item 5. Admin-only, view only — no `create`/`update`/`delete`
 * anywhere, on purpose: payments are financial records, only ever written
 * by SubscriptionService, never mutated from the admin panel (no refund
 * API wired). docs/06-security-architecture.md §3.3: "Moderators: ...
 * cannot touch subscription/payment data."
 */
class PaymentPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->isAdmin();
    }

    public function view(User $user, Payment $payment): bool
    {
        return $user->isAdmin();
    }
}
