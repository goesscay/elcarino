<?php

namespace App\Services\Admin;

use App\Models\AuditLogEntry;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;

/**
 * The single write path to `audit_log` (docs/06-security-architecture.md
 * §8) — every Filament action that changes account status or a report's
 * disposition goes through this, not a direct AuditLogEntry::create()
 * scattered per-resource, so "every admin/moderator action is logged" is
 * one call site to verify, not N.
 */
class AuditLogger
{
    /**
     * @param  array<string, mixed>  $before
     * @param  array<string, mixed>  $after
     */
    public function record(User $actor, string $action, ?Model $target = null, array $before = [], array $after = []): void
    {
        AuditLogEntry::query()->create([
            'actor_id' => $actor->id,
            'action' => $action,
            'target_type' => $target?->getMorphClass(),
            'target_id' => $target?->getKey(),
            'before' => $before,
            'after' => $after,
        ]);
    }
}
