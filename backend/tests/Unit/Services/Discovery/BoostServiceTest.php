<?php

namespace Tests\Unit\Services\Discovery;

use App\Models\Boost;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Discovery\BoostService;
use App\Services\Discovery\BoostUnavailableException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Phase 2 item 3 / open decision #14. "Frequency/limits" is
 * `subscription_plans.entitlements.boosts_per_month` — a real entitlement
 * value, not invented here.
 */
class BoostServiceTest extends TestCase
{
    use RefreshDatabase;

    private function service(): BoostService
    {
        return app(BoostService::class);
    }

    private function subscriber(int $boostsPerMonth = 1): User
    {
        $user = User::factory()->create();
        $plan = SubscriptionPlan::factory()->create(['entitlements' => ['boosts_per_month' => $boostsPerMonth]]);
        Subscription::factory()->for($user)->for($plan, 'plan')->create();

        return $user;
    }

    public function test_a_subscriber_can_activate_a_boost(): void
    {
        $user = $this->subscriber();

        $boost = $this->service()->activate($user);

        $this->assertTrue($boost->isActive());
        $this->assertSame(30, (int) $boost->starts_at->diffInMinutes($boost->ends_at));
        $this->assertDatabaseHas('boosts', ['user_id' => $user->id, 'source' => 'subscription_perk']);
    }

    public function test_a_free_user_cannot_activate_a_boost(): void
    {
        $user = User::factory()->create();

        try {
            $this->service()->activate($user);
            $this->fail('Expected a BoostUnavailableException.');
        } catch (BoostUnavailableException $e) {
            $this->assertSame('upgrade_required', $e->errorCode);
            $this->assertSame(403, $e->httpStatus);
        }
    }

    public function test_a_subscriber_whose_plan_grants_no_boosts_cannot_activate_one(): void
    {
        $user = $this->subscriber(boostsPerMonth: 0);

        try {
            $this->service()->activate($user);
            $this->fail('Expected a BoostUnavailableException.');
        } catch (BoostUnavailableException $e) {
            $this->assertSame('upgrade_required', $e->errorCode);
        }
    }

    public function test_activating_while_one_is_already_active_is_rejected(): void
    {
        $user = $this->subscriber();
        $this->service()->activate($user);

        try {
            $this->service()->activate($user);
            $this->fail('Expected a BoostUnavailableException.');
        } catch (BoostUnavailableException $e) {
            $this->assertSame('boost_already_active', $e->errorCode);
            $this->assertSame(409, $e->httpStatus);
        }
    }

    public function test_the_monthly_limit_is_enforced_once_the_active_boost_has_ended(): void
    {
        $user = $this->subscriber(boostsPerMonth: 1);
        Boost::factory()->for($user)->expired()->create();

        try {
            $this->service()->activate($user);
            $this->fail('Expected a BoostUnavailableException.');
        } catch (BoostUnavailableException $e) {
            $this->assertSame('boost_limit_reached', $e->errorCode);
            $this->assertSame(403, $e->httpStatus);
        }
    }

    public function test_a_boost_from_last_month_does_not_count_against_this_months_limit(): void
    {
        $user = $this->subscriber(boostsPerMonth: 1);
        Boost::factory()->for($user)->create([
            'starts_at' => now()->subMonthNoOverflow()->startOfMonth(),
            'ends_at' => now()->subMonthNoOverflow()->startOfMonth()->addMinutes(30),
            'created_at' => now()->subMonthNoOverflow()->startOfMonth(),
        ]);

        $boost = $this->service()->activate($user);

        $this->assertTrue($boost->isActive());
    }

    public function test_status_reports_used_count_and_limit(): void
    {
        $user = $this->subscriber(boostsPerMonth: 2);

        $before = $this->service()->status($user);
        $this->assertFalse($before['active']);
        $this->assertSame(0, $before['used_this_month']);
        $this->assertSame(2, $before['limit']);

        $this->service()->activate($user);
        $after = $this->service()->status($user);

        $this->assertTrue($after['active']);
        $this->assertNotNull($after['ends_at']);
        $this->assertSame(1, $after['used_this_month']);
    }

    public function test_status_for_a_free_user_reports_a_false_limit(): void
    {
        $status = $this->service()->status(User::factory()->create());

        $this->assertFalse($status['active']);
        $this->assertFalse($status['limit']);
    }
}
