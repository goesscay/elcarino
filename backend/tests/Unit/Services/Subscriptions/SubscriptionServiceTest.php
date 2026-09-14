<?php

namespace Tests\Unit\Services\Subscriptions;

use App\Enums\SubscriptionProvider;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Subscriptions\SubscriptionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use InvalidArgumentException;
use Tests\TestCase;

/**
 * The HTTP layer (StoreSubscriptionRequest) already blocks `provider:
 * "other"` before it ever reaches the service — this proves the service
 * itself also fails closed, not just the request validation in front of
 * it, same "every layer enforces it" discipline as the rest of this app.
 */
class SubscriptionServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_provider_other_is_rejected_at_the_service_layer_too(): void
    {
        $user = User::factory()->create();
        $plan = SubscriptionPlan::factory()->create();

        $this->expectException(InvalidArgumentException::class);
        app(SubscriptionService::class)->purchase($user, $plan, SubscriptionProvider::Other, null);
    }
}
