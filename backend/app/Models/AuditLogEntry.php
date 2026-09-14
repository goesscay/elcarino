<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * docs/02-database-schema.md `audit_log` / docs/06-security-architecture.md
 * §8. Written only by App\Services\Admin\AuditLogger — never updated or
 * deleted anywhere in the app, by design ("audit rows are never editable or
 * deletable through the app, including by admins").
 */
#[Fillable(['actor_id', 'action', 'target_type', 'target_id', 'before', 'after'])]
class AuditLogEntry extends Model
{
    protected $table = 'audit_log';

    /**
     * No `updated_at` column exists — see the migration's doc comment.
     */
    const UPDATED_AT = null;

    protected function casts(): array
    {
        return [
            'before' => 'array',
            'after' => 'array',
            'created_at' => 'datetime',
        ];
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }
}
