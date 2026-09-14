<?php

namespace Tests\Unit\Policies;

use App\Enums\UserRole;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Gate;
use Tests\TestCase;

/**
 * Phase 2 item 5. docs/06-security-architecture.md §3.3: "Moderators: ...
 * cannot change plans" — admin-only for everything, moderators excluded
 * entirely (not just hidden from the panel nav, the actual gate).
 */
class SubscriptionPlanPolicyTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_admins_can_view_and_manage_plans(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $moderator = User::factory()->create(['role' => UserRole::Moderator]);
        $plan = SubscriptionPlan::factory()->create();

        $this->assertTrue(Gate::forUser($admin)->allows('viewAny', SubscriptionPlan::class));
        $this->assertTrue(Gate::forUser($admin)->allows('view', $plan));
        $this->assertTrue(Gate::forUser($admin)->allows('create', SubscriptionPlan::class));
        $this->assertTrue(Gate::forUser($admin)->allows('update', $plan));
        $this->assertTrue(Gate::forUser($admin)->allows('delete', $plan));

        $this->assertFalse(Gate::forUser($moderator)->allows('viewAny', SubscriptionPlan::class));
        $this->assertFalse(Gate::forUser($moderator)->allows('view', $plan));
        $this->assertFalse(Gate::forUser($moderator)->allows('create', SubscriptionPlan::class));
        $this->assertFalse(Gate::forUser($moderator)->allows('update', $plan));
        $this->assertFalse(Gate::forUser($moderator)->allows('delete', $plan));
    }

    public function test_a_plain_user_cannot_view_or_manage_plans(): void
    {
        $user = User::factory()->create();
        $plan = SubscriptionPlan::factory()->create();

        $this->assertFalse(Gate::forUser($user)->allows('viewAny', SubscriptionPlan::class));
        $this->assertFalse(Gate::forUser($user)->allows('view', $plan));
    }
}
