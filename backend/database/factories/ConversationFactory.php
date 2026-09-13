<?php

namespace Database\Factories;

use App\Models\Conversation;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Conversation>
 */
class ConversationFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_one_id' => User::factory(),
            'user_two_id' => User::factory(),
        ];
    }

    /**
     * Sets user_one/two_id correctly ordered (lower id first) for a real
     * pair of existing users, mirroring SwipeService::createMatch().
     */
    public function between(User $a, User $b): static
    {
        return $this->state([
            'user_one_id' => min($a->id, $b->id),
            'user_two_id' => max($a->id, $b->id),
        ]);
    }
}
