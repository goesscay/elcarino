<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('type', [
                'new_match', 'new_message', 'like', 'subscription', 'verification', 'report_status', 'system',
            ]);
            $table->json('payload');
            $table->timestamp('read_at')->nullable();
            $table->boolean('sent_via_push')->default(false);
            // docs/02-database-schema.md doesn't list created_at for this
            // table, but "paginated, unread-first" (docs/03) still needs a
            // recency ordering within each of those two groups — added here,
            // documented in docs/02 in this commit, same reasoning as
            // `messages`' created_at-only (no updated_at: immutable creation
            // data + one mutable read_at, never touched otherwise).
            $table->timestamp('created_at')->useCurrent();
            $table->index(['user_id', 'read_at', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
