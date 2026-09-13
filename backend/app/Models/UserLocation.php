<?php

namespace App\Models;

use Database\Factories\UserLocationFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Exact coordinates — "Critical" data (docs/06 §5). Never exposed through an
 * API Resource another user can retrieve (docs/06 §4); the discovery feed
 * only ever reads this to compute a bucketed distance server-side.
 */
#[Fillable(['user_id', 'latitude', 'longitude', 'geohash'])]
class UserLocation extends Model
{
    /** @use HasFactory<UserLocationFactory> */
    use HasFactory;

    // This table has no created_at (docs/02-database-schema.md lists only
    // `updated_at`) — ambient state that's overwritten in place, not an
    // append-only record.
    const CREATED_AT = null;

    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
