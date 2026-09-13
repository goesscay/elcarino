<?php

namespace App\Models;

use App\Enums\SwipeDirection;
use Database\Factories\SwipeFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * The discovery feed (item 5) reads this table to exclude already-swiped
 * candidates; SwipeService (item 6) is what actually writes to it.
 */
#[Fillable(['actor_id', 'target_id', 'direction'])]
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
