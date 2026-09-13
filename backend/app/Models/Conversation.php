<?php

namespace App\Models;

use Database\Factories\ConversationFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable(['match_id', 'user_one_id', 'user_two_id', 'last_message_at'])]
class Conversation extends Model
{
    /** @use HasFactory<ConversationFactory> */
    use HasFactory, SoftDeletes;

    protected function casts(): array
    {
        return [
            'last_message_at' => 'datetime',
        ];
    }

    public function match(): BelongsTo
    {
        return $this->belongsTo(UserMatch::class, 'match_id');
    }

    public function userOne(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_one_id');
    }

    public function userTwo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_two_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class)->orderBy('created_at');
    }

    public function isParticipant(User $user): bool
    {
        return $this->user_one_id === $user->id || $this->user_two_id === $user->id;
    }

    public function otherUser(User $viewer): User
    {
        return $this->user_one_id === $viewer->id ? $this->userTwo : $this->userOne;
    }

    /**
     * docs/01-technical-specification.md §12 / docs/06 §3.4: messaging an
     * unmatched user requires an active subscription. A conversation with no
     * match at all (unmatched-messaging used from the start) is treated the
     * same as an unmatched one — either way there's no active match backing it.
     */
    public function requiresSubscriptionToMessage(): bool
    {
        return $this->match === null || ! $this->match->isActive();
    }
}
