<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * docs/02-database-schema.md `subscriptions`. `provider` mirrors open
     * decision #27 (payment gateway — unresolved): the enum supports all
     * three so nothing about the schema narrows that decision, even though
     * this feature only ships a working `stripe` gateway plus real-but-
     * unconfigured `app_store`/`play_store` receipt verifiers (see
     * App\Services\Payments). `other` exists in the enum for schema
     * completeness only — nothing in this app ever writes it.
     */
    public function up(): void
    {
        Schema::create('subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('plan_id')->constrained('subscription_plans');
            $table->enum('status', ['active', 'canceled', 'expired', 'past_due'])->default('active');
            $table->timestamp('started_at');
            $table->timestamp('ends_at');
            $table->enum('provider', ['app_store', 'play_store', 'stripe', 'other']);
            $table->string('provider_subscription_id')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'status', 'ends_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('subscriptions');
    }
};
