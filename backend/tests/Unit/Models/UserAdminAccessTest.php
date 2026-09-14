<?php

namespace Tests\Unit\Models;

use App\Enums\UserRole;
use App\Models\User;
use Filament\Panel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Tests\TestCase;

/**
 * docs/06-security-architecture.md §3.3: "admin login is not the mobile
 * Sanctum flow" — only admin/moderator roles reach the Filament panel at
 * all, and only admins may ban/delete. Phase 1 item 11.
 */
class UserAdminAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_admin_and_moderator_roles_can_access_the_panel(): void
    {
        $panel = Panel::make();

        $this->assertTrue(User::factory()->create(['role' => UserRole::Admin])->canAccessPanel($panel));
        $this->assertTrue(User::factory()->create(['role' => UserRole::Moderator])->canAccessPanel($panel));
        $this->assertFalse(User::factory()->create(['role' => UserRole::User])->canAccessPanel($panel));
    }

    public function test_only_admins_pass_the_ban_users_and_delete_users_gates(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $moderator = User::factory()->create(['role' => UserRole::Moderator]);

        $this->assertTrue(Gate::forUser($admin)->allows('banUsers'));
        $this->assertTrue(Gate::forUser($admin)->allows('deleteUsers'));
        $this->assertFalse(Gate::forUser($moderator)->allows('banUsers'));
        $this->assertFalse(Gate::forUser($moderator)->allows('deleteUsers'));
    }

    public function test_app_authentication_secret_and_recovery_codes_round_trip_encrypted(): void
    {
        $user = User::factory()->create();

        $user->saveAppAuthenticationSecret('SECRETKEY123');
        $user->saveAppAuthenticationRecoveryCodes(['code-one', 'code-two']);

        $this->assertSame('SECRETKEY123', $user->refresh()->getAppAuthenticationSecret());
        $this->assertSame(['code-one', 'code-two'], $user->getAppAuthenticationRecoveryCodes());

        // Encrypted at rest (docs/06 §5 "critical" data class) — the raw DB
        // column must never contain the plaintext secret.
        $raw = DB::table('users')->where('id', $user->id)->value('app_authentication_secret');
        $this->assertStringNotContainsString('SECRETKEY123', $raw);
    }
}
