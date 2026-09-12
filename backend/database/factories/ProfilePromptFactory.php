<?php

namespace Database\Factories;

use App\Models\ProfilePrompt;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ProfilePrompt>
 */
class ProfilePromptFactory extends Factory
{
    public function definition(): array
    {
        return [
            'prompt' => fake()->sentence().'…',
            'category' => fake()->randomElement(['About me', 'Dating', 'Fun']),
            'sort_order' => 0,
        ];
    }
}
