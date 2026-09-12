<?php

namespace App\Models;

use Database\Factories\InterestFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

/**
 * The interest catalogue (spec §6). Public-ish (docs/06 §5) but kept behind
 * auth for now, same as the prompt library — every route in this group is.
 */
class Interest extends Model
{
    /** @use HasFactory<InterestFactory> */
    use HasFactory;

    public function users(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'user_interests')->withTimestamps();
    }
}
