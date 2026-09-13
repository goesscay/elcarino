<?php

namespace Database\Factories;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Notification>
 */
class NotificationFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'type' => 'system',
            'payload' => [],
            'sent_via_push' => false,
        ];
    }

    public function read(): static
    {
        return $this->state(fn (array $attributes) => ['read_at' => now()]);
    }
}
