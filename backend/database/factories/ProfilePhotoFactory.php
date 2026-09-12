<?php

namespace Database\Factories;

use App\Models\Profile;
use App\Models\ProfilePhoto;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<ProfilePhoto>
 */
class ProfilePhotoFactory extends Factory
{
    public function definition(): array
    {
        return [
            'profile_id' => Profile::factory(),
            'storage_path' => 'photos/test/'.Str::uuid().'.jpg',
            'sort_order' => 0,
        ];
    }
}
