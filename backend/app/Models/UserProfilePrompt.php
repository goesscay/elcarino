<?php

namespace App\Models;

use Database\Factories\UserProfilePromptFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['prompt_id', 'answer', 'sort_order'])]
class UserProfilePrompt extends Model
{
    /** @use HasFactory<UserProfilePromptFactory> */
    use HasFactory;

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function prompt(): BelongsTo
    {
        return $this->belongsTo(ProfilePrompt::class, 'prompt_id');
    }
}
