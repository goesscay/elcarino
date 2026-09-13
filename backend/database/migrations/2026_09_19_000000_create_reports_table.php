<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('reported_id')->constrained('users')->cascadeOnDelete();
            $table->enum('category', [
                'harassment', 'fake_profile', 'spam', 'inappropriate_content', 'scam', 'other',
            ]);
            $table->text('description')->nullable();
            $table->enum('status', ['pending', 'reviewing', 'actioned', 'dismissed'])->default('pending');
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            // docs/02-database-schema.md doesn't list created_at/updated_at
            // for this table, but unlike messages/notifications a report's
            // own row genuinely gets mutated later (status/reviewed_by/
            // reviewed_at, by the admin queue — item 11) — full timestamps()
            // fit here where they didn't there. Documented in docs/02 in
            // this commit.
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reports');
    }
};
