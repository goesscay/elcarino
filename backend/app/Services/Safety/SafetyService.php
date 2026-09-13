<?php

namespace App\Services\Safety;

use App\Enums\ReportCategory;
use App\Models\Block;
use App\Models\Report;
use App\Models\User;
use App\Models\UserMatch;

/**
 * Phase 1 item 10. docs/07-ui-ux-design.md §3.7 "Block confirm": "Blocking
 * also unmatches" — enforced here, not left to the mobile UI, same
 * server-side-is-the-control discipline as every other safety rule in this
 * app (docs/06 §3.4).
 */
class SafetyService
{
    /**
     * Idempotent — blocking someone already blocked is a no-op success, not
     * a 422 (the `blocks` table's `unique(blocker_id, blocked_id)` would
     * otherwise throw on a repeat call, and there's no reason a client
     * retry or a double-tap should surface an error for this).
     */
    public function block(User $blocker, User $blocked): void
    {
        Block::query()->firstOrCreate([
            'blocker_id' => $blocker->id,
            'blocked_id' => $blocked->id,
        ]);

        $this->unmatchIfActive($blocker, $blocked);
    }

    /**
     * Also idempotent — unblocking someone not currently blocked just does
     * nothing, rather than needing the caller to check first.
     */
    public function unblock(User $blocker, int $blockedUserId): void
    {
        $blocker->blocksMade()->where('blocked_id', $blockedUserId)->delete();
    }

    public function report(
        User $reporter,
        User $reported,
        ReportCategory $category,
        ?string $description,
        bool $alsoBlock,
    ): Report {
        $report = Report::query()->create([
            'reporter_id' => $reporter->id,
            'reported_id' => $reported->id,
            'category' => $category,
            'description' => $description,
        ]);

        // docs/07 §3.7 "Report — detail": "option to also block". Reuses
        // block()'s own unmatch behavior rather than duplicating it.
        if ($alsoBlock) {
            $this->block($reporter, $reported);
        }

        return $report;
    }

    private function unmatchIfActive(User $userA, User $userB): void
    {
        UserMatch::query()
            ->where('user_one_id', min($userA->id, $userB->id))
            ->where('user_two_id', max($userA->id, $userB->id))
            ->whereNull('unmatched_at')
            ->first()
            ?->forceFill(['unmatched_at' => now(), 'unmatched_by' => $userA->id])
            ->save();
    }
}
