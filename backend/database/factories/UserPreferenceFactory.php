<?php

namespace Database\Factories;

use App\Enums\Gender;
use App\Models\User;
use App\Models\UserPreference;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<UserPreference>
 */
class UserPreferenceFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'min_age' => 18,
            'max_age' => 55,
            'max_distance_km' => 50,
            'interested_in_genders' => [Gender::Woman->value],
        ];
    }
}
