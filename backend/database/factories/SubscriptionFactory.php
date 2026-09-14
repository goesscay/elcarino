<?php

namespace Database\Factories;

use App\Enums\SubscriptionProvider;
use App\Enums\SubscriptionStatus;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Subscription>
 */
class SubscriptionFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'plan_id' => SubscriptionPlan::factory(),
            'status' => SubscriptionStatus::Active,
            'started_at' => now(),
            'ends_at' => now()->addMonth(),
            'provider' => SubscriptionProvider::Stripe,
            'provider_subscription_id' => 'sub_'.fake()->uuid(),
        ];
    }

    public function expired(): static
    {
        return $this->state(fn () => [
            'status' => SubscriptionStatus::Expired,
            'started_at' => now()->subMonths(2),
            'ends_at' => now()->subMonth(),
        ]);
    }

    public function canceled(): static
    {
        return $this->state(fn () => [
            'status' => SubscriptionStatus::Canceled,
            'ends_at' => now()->subDay(),
        ]);
    }
}
