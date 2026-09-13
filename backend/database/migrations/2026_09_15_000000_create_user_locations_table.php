<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_locations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->double('latitude');
            $table->double('longitude');
            $table->string('geohash')->index();
            // docs/02-database-schema.md lists only `updated_at` for this table
            // (no `created_at`) — ambient, overwritten-in-place state, not an
            // audit trail. See UserLocation::CREATED_AT = null.
            $table->timestamp('updated_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_locations');
    }
};
