<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Written on every right/super swipe (SwipeService), kept distinct
        // from `swipes` so a future "who liked me" query stays cheap
        // (docs/02-database-schema.md) — that query itself is
        // [PROPOSED]/premium-gated (docs/03 Matches group) and not built in
        // this feature.
        Schema::create('likes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('liked_user_id')->constrained('users')->cascadeOnDelete();
            $table->boolean('is_super')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('likes');
    }
};
