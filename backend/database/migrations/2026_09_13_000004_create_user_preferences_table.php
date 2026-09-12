<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_preferences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->smallInteger('min_age');
            $table->smallInteger('max_age');
            $table->smallInteger('max_distance_km');
            // JSON, not jsonb — portable across SQLite (local) and PostgreSQL (staging/prod)
            // per CLAUDE.md backend conventions.
            $table->json('interested_in_genders');
            $table->json('religion_filter')->nullable();
            $table->json('politics_filter')->nullable();
            $table->json('relationship_goal_filter')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_preferences');
    }
};
