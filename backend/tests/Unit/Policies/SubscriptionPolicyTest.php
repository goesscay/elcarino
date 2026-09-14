<?php

namespace Tests\Unit\Policies;

use App\Enums\UserRole;
use App\Models\Subscription;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Gate;
use Tests\TestCase;

/**
 * Phase 2 item 5. `viewAny`/`view` are admin-only, same as the other two
 * billing policies. `cancel` is the one ability shared with the mobile API
 * (a user cancelling their own subscription, since Phase 2 item 1) —
 * widened here to also allow an admin cancelling *someone else's* from the
 * panel, without narrowing what a plain user could already do to their own.
 */
class SubscriptionPolicyTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_admins_can_view_subscriptions(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $moderator = User::factory()->create(['role' => UserRole::Moderator]);
        $subscription = Subscription::factory()->create();

        $this->assertTrue(Gate::forUser($admin)->allows('viewAny', Subscription::class));
        $this->assertTrue(Gate::forUser($admin)->allows('view', $subscription));

        $this->assertFalse(Gate::forUser($moderator)->allows('viewAny', Subscription::class));
        $this->assertFalse(Gate::forUser($moderator)->allows('view', $subscription));
    }

    public function test_a_user_can_still_cancel_their_own_subscription(): void
    {
        $owner = User::factory()->create();
        $subscription = Subscription::factory()->for($owner)->create();

        $this->assertTrue(Gate::forUser($owner)->allows('cancel', $subscription));
    }

    public function test_a_user_cannot_cancel_someone_elses_subscription(): void
    {
        $owner = User::factory()->create();
        $stranger = User::factory()->create();
        $subscription = Subscription::factory()->for($owner)->create();

        $this->assertFalse(Gate::forUser($stranger)->allows('cancel', $subscription));
    }

    public function test_an_admin_can_cancel_anyones_subscription(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $owner = User::factory()->create();
        $subscription = Subscription::factory()->for($owner)->create();

        $this->assertTrue(Gate::forUser($admin)->allows('cancel', $subscription));
    }

    public function test_a_moderator_cannot_cancel_someone_elses_subscription(): void
    {
        $moderator = User::factory()->create(['role' => UserRole::Moderator]);
        $owner = User::factory()->create();
        $subscription = Subscription::factory()->for($owner)->create();

        $this->assertFalse(Gate::forUser($moderator)->allows('cancel', $subscription));
    }
}
