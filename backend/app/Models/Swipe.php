<?php

namespace App\Models;

use App\Enums\SwipeDirection;
use Database\Factories\SwipeFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Minimal for now — enough for the discovery feed (item 5) to exclude
 * already-swiped candidates by reading this table. The write path
 * (POST /swipes, match detection) is Phase 1 item 6.
 */
class Swipe extends Model
{
    /** @use HasFactory<SwipeFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'direction' => SwipeDirection::class,
        ];
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }

    public function target(): BelongsTo
    {
        return $this->belongsTo(User::class, 'target_id');
    }
}
