<?php

namespace Database\Factories;

use App\Enums\BoostSource;
use App\Models\Boost;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Boost>
 */
class BoostFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'starts_at' => now(),
            'ends_at' => now()->addMinutes(30),
            'source' => BoostSource::SubscriptionPerk,
        ];
    }

    public function expired(): static
    {
        return $this->state(fn () => [
            'starts_at' => now()->subHours(2),
            'ends_at' => now()->subHour(),
        ]);
    }
}
