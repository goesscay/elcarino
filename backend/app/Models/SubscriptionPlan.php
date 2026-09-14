<?php

namespace App\Models;

use App\Enums\BillingInterval;
use Database\Factories\SubscriptionPlanFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * docs/02-database-schema.md `subscription_plans`. `entitlements` is the
 * one thing gated endpoints actually read (docs/06-security-architecture.md
 * §3.4's `user->entitlement($key)`) — deliberately not typed columns per
 * entitlement, so a new gate is a data change, not a migration.
 */
#[Fillable(['name', 'price_cents', 'currency', 'billing_interval', 'entitlements', 'is_active'])]
class SubscriptionPlan extends Model
{
    /** @use HasFactory<SubscriptionPlanFactory> */
    use HasFactory;

    protected $attributes = [
        'is_active' => true,
    ];

    protected function casts(): array
    {
        return [
            'billing_interval' => BillingInterval::class,
            'entitlements' => 'array',
            'is_active' => 'boolean',
        ];
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class, 'plan_id');
    }
}
