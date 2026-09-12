<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // docs/02-database-schema.md: composite PK (user_id, interest_id), no
        // surrogate id — a pure pivot, unlike user_profile_prompts which
        // carries its own extra columns (answer, sort_order).
        Schema::create('user_interests', function (Blueprint $table) {
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('interest_id')->constrained()->cascadeOnDelete();
            $table->timestamps();
            $table->primary(['user_id', 'interest_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_interests');
    }
};
