<?php

namespace App\Models;

use Database\Factories\UserMatchFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Maps to the `matches` table (docs/02-database-schema.md) — named UserMatch,
 * not Match, because `match` is a reserved word in PHP 8+ and can't be used
 * as a class name.
 */
#[Fillable(['user_one_id', 'user_two_id', 'matched_at', 'unmatched_at', 'unmatched_by'])]
class UserMatch extends Model
{
    /** @use HasFactory<UserMatchFactory> */
    use HasFactory;

    protected $table = 'matches';

    protected function casts(): array
    {
        return [
            'matched_at' => 'datetime',
            'unmatched_at' => 'datetime',
        ];
    }

    public function userOne(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_one_id');
    }

    public function userTwo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_two_id');
    }

    public function unmatchedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'unmatched_by');
    }

    public function isParticipant(User $user): bool
    {
        return $this->user_one_id === $user->id || $this->user_two_id === $user->id;
    }

    public function otherUser(User $viewer): User
    {
        return $this->user_one_id === $viewer->id ? $this->userTwo : $this->userOne;
    }

    public function isActive(): bool
    {
        return $this->unmatched_at === null;
    }
}
