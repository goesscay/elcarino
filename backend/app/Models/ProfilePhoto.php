<?php

namespace App\Models;

use App\Enums\PhotoModerationStatus;
use Database\Factories\ProfilePhotoFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['storage_path', 'sort_order'])]
#[Hidden(['storage_path'])] // never expose the raw disk key — clients get a signed `url` (see ProfilePhotoResource)
class ProfilePhoto extends Model
{
    /** @use HasFactory<ProfilePhotoFactory> */
    use HasFactory;

    protected $attributes = [
        'moderation_status' => 'pending',
    ];

    protected function casts(): array
    {
        return [
            'moderation_status' => PhotoModerationStatus::class,
        ];
    }

    public function profile(): BelongsTo
    {
        return $this->belongsTo(Profile::class);
    }
}
