<?php

namespace App\Models;

use App\Enums\SubscriptionProvider;
use App\Enums\SubscriptionStatus;
use Database\Factories\SubscriptionFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * docs/02-database-schema.md `subscriptions`. Written only by
 * App\Services\Subscriptions\SubscriptionService — never a raw
 * controller-level create/update, same discipline as Report/User status
 * changes in the admin panel (Phase 1 item 11).
 */
#[Fillable(['user_id', 'plan_id', 'status', 'started_at', 'ends_at', 'provider', 'provider_subscription_id'])]
class Subscription extends Model
{
    /** @use HasFactory<SubscriptionFactory> */
    use HasFactory;

    protected $attributes = [
        'status' => 'active',
    ];

    protected function casts(): array
    {
        return [
            'status' => SubscriptionStatus::class,
            'provider' => SubscriptionProvider::class,
            'started_at' => 'datetime',
            'ends_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(SubscriptionPlan::class, 'plan_id');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    /**
     * The one place "is this subscription actually granting access right
     * now" is decided — reused by both User::currentSubscription()'s query
     * and anything else that later needs the same check on an
     * already-loaded instance rather than a fresh query.
     */
    public function isActive(): bool
    {
        return $this->status === SubscriptionStatus::Active && $this->ends_at->isFuture();
    }
}
