<?php

namespace App\Models;

use App\Enums\BoostSource;
use Database\Factories\BoostFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * docs/02-database-schema.md `boosts`. Written only by
 * App\Services\Discovery\BoostService.
 */
#[Fillable(['user_id', 'starts_at', 'ends_at', 'source'])]
class Boost extends Model
{
    /** @use HasFactory<BoostFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'source' => BoostSource::class,
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isActive(): bool
    {
        return $this->starts_at->isPast() && $this->ends_at->isFuture();
    }
}
