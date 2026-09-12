<?php

namespace App\Models;

use Database\Factories\ProfilePromptFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * The curated prompt library (spec §7). Public-ish data — cacheable,
 * unauthenticated GET allowed (docs/06-security-architecture.md §5).
 */
class ProfilePrompt extends Model
{
    /** @use HasFactory<ProfilePromptFactory> */
    use HasFactory;

    protected $attributes = [
        'is_active' => true,
        'sort_order' => 0,
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function answers(): HasMany
    {
        return $this->hasMany(UserProfilePrompt::class, 'prompt_id');
    }
}
