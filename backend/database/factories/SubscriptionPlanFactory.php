<?php

namespace Database\Factories;

use App\Enums\BillingInterval;
use App\Models\SubscriptionPlan;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<SubscriptionPlan>
 */
class SubscriptionPlanFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => 'Premium (test)',
            // A placeholder for tests/local dev only — open decision #12
            // ("pricing — not set") is not answered by this number.
            'price_cents' => 999,
            'currency' => 'USD',
            'billing_interval' => BillingInterval::Monthly,
            'entitlements' => [
                'unlimited_likes' => true,
                'advanced_filters' => true,
                'boosts_per_month' => 1,
                'unmatched_messaging' => true,
            ],
            'is_active' => true,
        ];
    }
}
