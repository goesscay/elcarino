<?php

namespace Database\Factories;

use App\Models\ProfilePrompt;
use App\Models\User;
use App\Models\UserProfilePrompt;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<UserProfilePrompt>
 */
class UserProfilePromptFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'prompt_id' => ProfilePrompt::factory(),
            'answer' => fake()->sentence(),
            'sort_order' => 0,
        ];
    }
}
