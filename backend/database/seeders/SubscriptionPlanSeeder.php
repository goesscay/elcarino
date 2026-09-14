<?php

namespace Database\Seeders;

use App\Enums\BillingInterval;
use App\Models\SubscriptionPlan;
use Illuminate\Database\Seeder;

/**
 * One premium plan so local dev/manual QA has something purchasable.
 * `price_cents` here is a placeholder for local testing, not a business
 * decision — open decision #12 (pricing) is "not set — no figures in any
 * client-facing material yet," and nothing in this app treats this seeded
 * value as a real price. Real plan management (creating/editing plans with
 * real pricing) is Phase 2's separate "Subscription management in admin
 * panel" item.
 */
class SubscriptionPlanSeeder extends Seeder
{
    public function run(): void
    {
        SubscriptionPlan::query()->updateOrCreate(
            ['name' => 'Premium'],
            [
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
            ],
        );
    }
}
