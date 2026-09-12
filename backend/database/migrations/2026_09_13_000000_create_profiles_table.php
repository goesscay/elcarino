<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('display_name');
            $table->date('birth_date');
            $table->enum('gender', ['man', 'woman', 'non_binary']);
            $table->text('bio')->nullable();
            $table->string('relationship_goal')->nullable();
            $table->boolean('is_verified')->default(false);
            $table->smallInteger('completion_pct')->default(0);
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('profiles');
    }
};
