<?php

namespace App\Models;

use Database\Factories\BlockFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * The write path (`POST`/`DELETE /safety/block`) is Phase 1 item 10 —
 * `#[Fillable]` was unneeded before that (every prior use went through
 * `Block::factory()`, which bypasses mass-assignment guarding entirely).
 */
#[Fillable(['blocker_id', 'blocked_id'])]
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
