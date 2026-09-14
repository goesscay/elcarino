<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * docs/02-database-schema.md `subscription_plans`. Pricing lives here as
     * data, not in code — CLAUDE.md is explicit that a price is a business
     * decision, not an implementation detail (open decision #12: "not set —
     * no figures in any client-facing material yet"), so nothing in this
     * feature hardcodes one. `entitlements` keeps the actual feature gates
     * (unlimited_likes, boosts_per_month, advanced_filters, ...)
     * migration-free per docs/02's own note. Real plan management (create/
     * edit plans, set real pricing) is Phase 2's separate "Subscription
     * management in admin panel" item — not this one.
     */
    public function up(): void
    {
        Schema::create('subscription_plans', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->integer('price_cents');
            $table->char('currency', 3);
            $table->enum('billing_interval', ['monthly', 'quarterly', 'annual']);
            // JSON, not jsonb — portable across SQLite (local) and PostgreSQL
            // (staging/prod), same as user_preferences' filter columns.
            $table->json('entitlements');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('subscription_plans');
    }
};
