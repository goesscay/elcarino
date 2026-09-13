<?php

namespace Database\Factories;

use App\Enums\SwipeDirection;
use App\Models\Swipe;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Swipe>
 */
class SwipeFactory extends Factory
{
    public function definition(): array
    {
        return [
            'actor_id' => User::factory(),
            'target_id' => User::factory(),
            'direction' => fake()->randomElement(SwipeDirection::cases()),
        ];
    }
}
