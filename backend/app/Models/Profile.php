<?php

namespace App\Models;

use App\Enums\Gender;
use Database\Factories\ProfileFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable(['display_name', 'birth_date', 'gender', 'bio', 'relationship_goal'])]
class Profile extends Model
{
    /** @use HasFactory<ProfileFactory> */
    use HasFactory, SoftDeletes;

    protected $attributes = [
        'is_verified' => false,
        'completion_pct' => 0,
    ];

    protected function casts(): array
    {
        return [
            'birth_date' => 'date',
            'gender' => Gender::class,
            'is_verified' => 'boolean',
            'completion_pct' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function photos(): HasMany
    {
        return $this->hasMany(ProfilePhoto::class)->orderBy('sort_order');
    }

    /**
     * Cosmetic "profile completion" gamification meter (spec §17). No formula
     * is specified by the client — this is a provisional, documented weighting
     * (not one of the 30 tracked open decisions), safe to retune later:
     * basics 40 + a photo 30 + a prompt answer 15 + preferences saved 15.
     */
    public function recalculateCompletion(): void
    {
        $pct = 0;

        if ($this->display_name && $this->birth_date && $this->gender) {
            $pct += 40;
        }
        if ($this->photos()->exists()) {
            $pct += 30;
        }
        if (UserProfilePrompt::query()->where('user_id', $this->user_id)->exists()) {
            $pct += 15;
        }
        if (UserPreference::query()->where('user_id', $this->user_id)->exists()) {
            $pct += 15;
        }

        $this->forceFill(['completion_pct' => $pct])->save();
    }
}
