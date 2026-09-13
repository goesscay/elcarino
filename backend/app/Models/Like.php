<?php

namespace App\Models;

use Database\Factories\LikeFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Written on every right/super swipe (SwipeService) — see the migration's
 * doc comment for why this is distinct from `swipes`. Nothing reads this
 * table yet; "who liked me" is [PROPOSED]/premium (docs/03).
 */
#[Fillable(['user_id', 'liked_user_id', 'is_super'])]
class Like extends Model
{
    /** @use HasFactory<LikeFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'is_super' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function likedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'liked_user_id');
    }
}
