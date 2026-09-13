<?php

namespace Database\Factories;

use App\Models\User;
use App\Models\UserMatch;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<UserMatch>
 */
class UserMatchFactory extends Factory
{
    protected $model = UserMatch::class;

    public function definition(): array
    {
        return [
            'user_one_id' => User::factory(),
            'user_two_id' => User::factory(),
            'matched_at' => now(),
        ];
    }

    /**
     * Sets user_one/two_id correctly ordered (lower id first) for a real
     * pair of existing users — mirrors SwipeService::createMatch().
     */
    public function between(User $a, User $b): static
    {
        return $this->state([
            'user_one_id' => min($a->id, $b->id),
            'user_two_id' => max($a->id, $b->id),
        ]);
    }

    public function unmatched(): static
    {
        return $this->state(fn (array $attributes) => [
            'unmatched_at' => now(),
        ]);
    }
}
