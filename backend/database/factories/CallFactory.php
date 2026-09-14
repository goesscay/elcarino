<?php

namespace Database\Factories;

use App\Enums\CallStatus;
use App\Enums\CallType;
use App\Models\Call;
use App\Models\Conversation;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Call>
 */
class CallFactory extends Factory
{
    public function definition(): array
    {
        return [
            'conversation_id' => Conversation::factory(),
            'caller_id' => User::factory(),
            'callee_id' => User::factory(),
            'type' => CallType::Voice,
            'status' => CallStatus::Ringing,
        ];
    }

    public function active(): static
    {
        return $this->state(fn () => [
            'status' => CallStatus::Active,
            'started_at' => now()->subMinute(),
        ]);
    }

    public function ended(): static
    {
        return $this->state(fn () => [
            'status' => CallStatus::Ended,
            'started_at' => now()->subMinutes(5),
            'ended_at' => now(),
            'duration_seconds' => 300,
        ]);
    }
}
