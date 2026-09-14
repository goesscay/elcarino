<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * docs/02-database-schema.md `boosts` (schema-only until now — Phase 2
     * item 3). `source` already anticipated two ways a boost gets granted:
     * `subscription_perk` (this feature — spends one of the plan's monthly
     * `boosts_per_month` allotment) and `purchase` (a standalone a-la-carte
     * boost bought outside a subscription) — only the former is built here;
     * `purchase` stays a valid enum value with no writer yet, flagged not
     * silently dropped, same treatment as `subscriptions.provider`'s
     * `other` case.
     */
    public function up(): void
    {
        Schema::create('boosts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('starts_at');
            $table->timestamp('ends_at');
            $table->enum('source', ['purchase', 'subscription_perk']);
            $table->timestamps();
            $table->index(['user_id', 'starts_at', 'ends_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('boosts');
    }
};
