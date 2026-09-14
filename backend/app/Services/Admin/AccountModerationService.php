<?php

namespace App\Services\Admin;

use App\Enums\UserStatus;
use App\Models\User;
use RuntimeException;

/**
 * docs/06-security-architecture.md §9 "Account lifecycle": suspend/ban
 * revoke existing tokens immediately, and the Phase 1 gate
 * (docs/04-development-phases.md) requires that suspending a user "takes
 * effect immediately" — the token revocation here, plus the status checks
 * added alongside this feature to AuthController (login), DiscoveryFeedService
 * (feed), and ConversationPolicy (message freeze), are jointly what makes
 * that true. A status flag nobody reads would not be.
 */
class AccountModerationService
{
    public function __construct(private readonly AuditLogger $audit) {}

    /**
     * Reversible — docs/06 §9 "Suspend: ... Reversible."
     */
    public function suspend(User $actor, User $target, ?string $reason = null): void
    {
        $this->transition($actor, $target, UserStatus::Suspended, 'user.suspended', $reason);
    }

    /**
     * Only a suspended account can be reinstated — docs/06 §9 explicitly
     * calls suspend "Reversible" but describes ban as "permanent"; nothing
     * in this app's admin UI should offer reinstating a ban.
     */
    public function reinstate(User $actor, User $target): void
    {
        if ($target->status !== UserStatus::Suspended) {
            throw new RuntimeException('Only a suspended account can be reinstated.');
        }

        $this->transition($actor, $target, UserStatus::Active, 'user.reinstated');
    }

    /**
     * docs/06 §9 "Ban: as suspend, permanent." Content retention/purge after
     * the legal-hold window is a background-job concern not built yet
     * (same [PROPOSED] status as the rest of that retention job) — flagged,
     * not silently dropped.
     */
    public function ban(User $actor, User $target, ?string $reason = null): void
    {
        $this->transition($actor, $target, UserStatus::Banned, 'user.banned', $reason);
    }

    /**
     * Admin-initiated deletion. Mirrors the user-initiated lifecycle
     * (docs/06 §9): status -> deleted + soft-delete now; the background
     * hard-delete/anonymization job for the retention window is the same
     * one that path needs and isn't built yet — [PROPOSED], flagged not
     * dropped, same as the rest of that job's scope.
     */
    public function delete(User $actor, User $target, ?string $reason = null): void
    {
        $before = ['status' => $target->status->value];
        $target->forceFill(['status' => UserStatus::Deleted])->save();
        $target->tokens()->delete();
        $target->delete();

        $this->audit->record($actor, 'user.deleted', $target, $before, [
            'status' => UserStatus::Deleted->value,
            'reason' => $reason,
        ]);
    }

    private function transition(User $actor, User $target, UserStatus $to, string $action, ?string $reason = null): void
    {
        $before = ['status' => $target->status->value];
        $target->forceFill(['status' => $to])->save();
        $target->tokens()->delete();

        $this->audit->record($actor, $action, $target, $before, [
            'status' => $to->value,
            'reason' => $reason,
        ]);
    }
}
