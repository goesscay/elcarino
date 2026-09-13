<?php

namespace App\Models;

use App\Enums\DevicePlatform;
use Database\Factories\UserDeviceFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * docs/02-database-schema.md `user_devices`. No created_at/updated_at
 * (ambient device state, not an audit trail) — see the migration.
 */
#[Fillable(['user_id', 'fcm_token', 'platform', 'app_version', 'last_seen_at'])]
class UserDevice extends Model
{
    /** @use HasFactory<UserDeviceFactory> */
    use HasFactory;

    public $timestamps = false;

    protected function casts(): array
    {
        return [
            'platform' => DevicePlatform::class,
            'last_seen_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
