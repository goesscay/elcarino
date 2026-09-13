<?php

namespace App\Models;

use Database\Factories\BlockFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Minimal for now — enough for the discovery feed (item 5) to exclude
 * blocked users in both directions by reading this table. The write path
 * (POST /safety/block) is Phase 1 item 10.
 */
class Block extends Model
{
    /** @use HasFactory<BlockFactory> */
    use HasFactory;

    public function blocker(): BelongsTo
    {
        return $this->belongsTo(User::class, 'blocker_id');
    }

    public function blocked(): BelongsTo
    {
        return $this->belongsTo(User::class, 'blocked_id');
    }
}
