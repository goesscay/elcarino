<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Schema only, ahead of need: the discovery feed (Phase 1 item 5)
        // reads this table to exclude already-swiped candidates, but nothing
        // writes to it yet — POST /swipes is item 6.
        Schema::create('swipes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('actor_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('target_id')->constrained('users')->cascadeOnDelete();
            $table->enum('direction', ['left', 'right', 'super']);
            $table->timestamps();

            $table->unique(['actor_id', 'target_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('swipes');
    }
};
