<?php

namespace App\Models;

use App\Enums\NotificationType;
use Database\Factories\NotificationFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * docs/02-database-schema.md `notifications`. Deliberately named
 * `App\Models\Notification`, distinct from `User`'s (unused) built-in
 * `Illuminate\Notifications\Notifiable::notifications()` relation, which
 * targets a differently-shaped table Laravel never actually migrates here —
 * see `User::appNotifications()`'s doc comment.
 */
#[Fillable(['user_id', 'type', 'payload', 'read_at', 'sent_via_push'])]
class Notification extends Model
{
    /** @use HasFactory<NotificationFactory> */
    use HasFactory;

    const UPDATED_AT = null;

    protected function casts(): array
    {
        return [
            'type' => NotificationType::class,
            'payload' => 'array',
            'read_at' => 'datetime',
            'sent_via_push' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isRead(): bool
    {
        return $this->read_at !== null;
    }
}
