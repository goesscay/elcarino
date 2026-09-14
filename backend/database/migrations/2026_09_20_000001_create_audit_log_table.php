<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * docs/06-security-architecture.md §8: "An append-only audit_log table
     * ... records every admin/moderator action ... every moderation
     * decision ... every account status change." "Audit rows are never
     * editable or deletable through the app, including by admins" — hence
     * no updated_at (nothing about a row is ever mutated after insert, see
     * AuditLogEntry::UPDATED_AT) and `actor_id` is nullOnDelete rather than
     * cascade — a later-deleted admin account must not take the historical
     * record of what they did along with it. Added to docs/02 in this
     * commit, same as every other table.
     */
    public function up(): void
    {
        Schema::create('audit_log', function (Blueprint $table) {
            $table->id();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('action');
            $table->string('target_type')->nullable();
            $table->unsignedBigInteger('target_id')->nullable();
            $table->json('before')->nullable();
            $table->json('after')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->index(['target_type', 'target_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_log');
    }
};
