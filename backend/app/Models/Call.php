<?php

namespace App\Models;

use App\Enums\CallStatus;
use App\Enums\CallType;
use Database\Factories\CallFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * docs/02-database-schema.md `calls`. Written by
 * App\Http\Controllers\Api\Calls\CallController only.
 */
#[Fillable([
    'conversation_id', 'caller_id', 'callee_id', 'type', 'status',
    'started_at', 'ended_at', 'ended_by', 'duration_seconds',
])]
class Call extends Model
{
    /** @use HasFactory<CallFactory> */
    use HasFactory;

    protected $attributes = [
        'status' => 'ringing',
    ];

    protected function casts(): array
    {
        return [
            'type' => CallType::class,
            'status' => CallStatus::class,
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
        ];
    }

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class);
    }

    public function caller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'caller_id');
    }

    public function callee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'callee_id');
    }

    public function endedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'ended_by');
    }

    public function isParticipant(User $user): bool
    {
        return $this->caller_id === $user->id || $this->callee_id === $user->id;
    }
}
