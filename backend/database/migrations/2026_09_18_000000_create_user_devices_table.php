<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            // Unique, not just indexed (docs/02-database-schema.md lists it
            // plain) — a real FCM token identifies one app installation. If
            // that installation logs out and a different account logs back
            // in on the same device, the token gets re-registered under the
            // new user rather than duplicated (see UserDeviceController).
            $table->string('fcm_token')->unique();
            $table->enum('platform', ['ios', 'android']);
            $table->string('app_version')->nullable();
            // docs/02-database-schema.md lists only `last_seen_at` for this
            // table (no created_at/updated_at) — ambient device state, not an
            // audit trail, same reasoning as user_locations. Not nullable —
            // always set to now() on both register and re-register
            // (UserDeviceController), so there's no "registered but never
            // seen" state to represent.
            $table->timestamp('last_seen_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_devices');
    }
};
