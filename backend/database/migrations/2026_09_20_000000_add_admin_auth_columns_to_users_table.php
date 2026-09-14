<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * docs/06-security-architecture.md §3.3: admin/moderator panel login
     * "uses session auth with mandatory 2FA (TOTP)" — a firm requirement,
     * not a TBD. Filament v5 ships TOTP app-authentication built in
     * (Filament\Auth\MultiFactor\App\AppAuthentication); these two columns
     * are exactly what its HasAppAuthentication/HasAppAuthenticationRecovery
     * contracts need from the user model. Not in docs/02's original `users`
     * table (the admin panel wasn't built yet) — added to that doc in this
     * commit. Both are secrets (docs/06 §5 "critical" data class): cast
     * encrypted/encrypted:array on the model (see User::casts()), and never
     * selected by a mobile-facing API Resource — this is admin-panel-only
     * surface, unrelated to the mobile Sanctum auth flow.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->text('app_authentication_secret')->nullable()->after('role');
            $table->text('app_authentication_recovery_codes')->nullable()->after('app_authentication_secret');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['app_authentication_secret', 'app_authentication_recovery_codes']);
        });
    }
};
