<?php

namespace Tests\Unit\Models;

use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Phase 2 item 1: User::isSubscriber() was a hardcoded `return false` stub
 * until this feature (docs/01 §16/§17) — every existing call site
 * (RateLimiter::for('swipes', ...), ConversationPolicy/ChatController's
 * unmatched-messaging gate) already reads it, so this is the whole
 * integration surface for both.
 */
class UserSubscriptionTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_with_no_subscription_is_not_a_subscriber(): void
    {
        $user = User::factory()->create();

        $this->assertFalse($user->isSubscriber());
        $this->assertNull($user->currentSubscription());
        $this->assertFalse($user->entitlement('unlimited_likes'));
    }

    public function test_an_active_unexpired_subscription_makes_a_subscriber(): void
    {
        $plan = SubscriptionPlan::factory()->create(['entitlements' => ['unlimited_likes' => true, 'boosts_per_month' => 2]]);
        $user = User::factory()->create();
        Subscription::factory()->for($user)->for($plan, 'plan')->create();

        $this->assertTrue($user->isSubscriber());
        $this->assertTrue($user->entitlement('unlimited_likes'));
        $this->assertSame(2, $user->entitlement('boosts_per_month'));
        $this->assertFalse($user->entitlement('advanced_filters'));
    }

    public function test_an_expired_subscription_does_not_count(): void
    {
        $user = User::factory()->create();
        Subscription::factory()->for($user)->expired()->create();

        $this->assertFalse($user->isSubscriber());
    }

    public function test_a_canceled_subscription_does_not_count(): void
    {
        $user = User::factory()->create();
        Subscription::factory()->for($user)->canceled()->create();

        $this->assertFalse($user->isSubscriber());
    }

    public function test_the_most_recently_ending_active_subscription_wins(): void
    {
        $user = User::factory()->create();
        $olderPlan = SubscriptionPlan::factory()->create(['name' => 'Old']);
        $newerPlan = SubscriptionPlan::factory()->create(['name' => 'New']);
        Subscription::factory()->for($user)->for($olderPlan, 'plan')->create(['ends_at' => now()->addDays(5)]);
        Subscription::factory()->for($user)->for($newerPlan, 'plan')->create(['ends_at' => now()->addDays(30)]);

        $this->assertSame('New', $user->currentSubscription()->plan->name);
    }
}
