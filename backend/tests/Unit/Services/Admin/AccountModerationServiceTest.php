<?php

namespace Tests\Unit\Services\Admin;

use App\Enums\UserRole;
use App\Enums\UserStatus;
use App\Models\AuditLogEntry;
use App\Models\User;
use App\Services\Admin\AccountModerationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

/**
 * Phase 1 item 11. docs/06-security-architecture.md §9 ("Suspend: ...
 * Reversible." / "Ban: as suspend, permanent.") and the Phase 1 gate
 * (docs/04): "admin can suspend a user and it takes effect immediately" —
 * "immediately" here means the existing token is gone, not just a status
 * flag flipped.
 */
class AccountModerationServiceTest extends TestCase
{
    use RefreshDatabase;

    private function service(): AccountModerationService
    {
        return app(AccountModerationService::class);
    }

    public function test_suspend_revokes_tokens_and_logs_an_audit_entry(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $target = User::factory()->create();
        $target->createToken('device');
        $this->assertSame(1, $target->tokens()->count());

        $this->service()->suspend($admin, $target, 'spam reports');

        $target->refresh();
        $this->assertSame(UserStatus::Suspended, $target->status);
        $this->assertSame(0, $target->tokens()->count());
        $this->assertDatabaseHas('audit_log', [
            'actor_id' => $admin->id,
            'action' => 'user.suspended',
            'target_type' => $target->getMorphClass(),
            'target_id' => $target->id,
        ]);

        $entry = AuditLogEntry::query()->where('target_id', $target->id)->first();
        $this->assertSame(['status' => 'active'], $entry->before);
        $this->assertSame(['status' => 'suspended', 'reason' => 'spam reports'], $entry->after);
    }

    public function test_reinstate_restores_a_suspended_account(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $target = User::factory()->create(['status' => UserStatus::Suspended]);

        $this->service()->reinstate($admin, $target);

        $this->assertSame(UserStatus::Active, $target->refresh()->status);
        $this->assertDatabaseHas('audit_log', ['actor_id' => $admin->id, 'action' => 'user.reinstated']);
    }

    public function test_a_banned_account_cannot_be_reinstated(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $target = User::factory()->create(['status' => UserStatus::Banned]);

        try {
            $this->service()->reinstate($admin, $target);
            $this->fail('Expected a RuntimeException.');
        } catch (RuntimeException) {
            // expected
        }

        $this->assertSame(UserStatus::Banned, $target->refresh()->status);
    }

    public function test_ban_revokes_tokens_and_logs_an_audit_entry(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $target = User::factory()->create();
        $target->createToken('device');

        $this->service()->ban($admin, $target, 'illegal content');

        $target->refresh();
        $this->assertSame(UserStatus::Banned, $target->status);
        $this->assertSame(0, $target->tokens()->count());
        $this->assertDatabaseHas('audit_log', ['actor_id' => $admin->id, 'action' => 'user.banned']);
    }

    public function test_delete_soft_deletes_revokes_tokens_and_logs_an_audit_entry(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $target = User::factory()->create();
        $target->createToken('device');

        $this->service()->delete($admin, $target, 'user requested via support');

        $this->assertSoftDeleted($target);
        $this->assertSame(0, $target->tokens()->count());
        $this->assertDatabaseHas('audit_log', ['actor_id' => $admin->id, 'action' => 'user.deleted']);

        // status is 'deleted' on the (soft-deleted) row itself.
        $this->assertSame(
            UserStatus::Deleted,
            User::withTrashed()->find($target->id)->status,
        );
    }
}
