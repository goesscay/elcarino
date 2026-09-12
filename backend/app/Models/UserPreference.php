<?php

namespace App\Models;

use Database\Factories\UserPreferenceFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['min_age', 'max_age', 'max_distance_km', 'interested_in_genders', 'religion_filter', 'politics_filter', 'relationship_goal_filter'])]
class UserPreference extends Model
{
    /** @use HasFactory<UserPreferenceFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'interested_in_genders' => 'array',
            'religion_filter' => 'array',
            'politics_filter' => 'array',
            'relationship_goal_filter' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
