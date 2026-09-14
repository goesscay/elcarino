<?php

namespace Tests\Unit\Policies;

use App\Enums\UserRole;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Gate;
use Tests\TestCase;

/**
 * Phase 2 item 5. docs/06-security-architecture.md §3.3: "Moderators: ...
 * cannot touch subscription/payment data."
 */
class PaymentPolicyTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_admins_can_view_payments(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $moderator = User::factory()->create(['role' => UserRole::Moderator]);
        $user = User::factory()->create();
        $payment = Payment::factory()->create();

        $this->assertTrue(Gate::forUser($admin)->allows('viewAny', Payment::class));
        $this->assertTrue(Gate::forUser($admin)->allows('view', $payment));

        $this->assertFalse(Gate::forUser($moderator)->allows('viewAny', Payment::class));
        $this->assertFalse(Gate::forUser($moderator)->allows('view', $payment));

        $this->assertFalse(Gate::forUser($user)->allows('viewAny', Payment::class));
    }
}
