<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
            // Text only — Phase 1 item 8's explicit scope. `type` still
            // matches docs/02's full enum (voice_note/gif/photo included) so
            // no migration change is needed if #16/17/18 are later confirmed
            // in scope; `body` nullable per that same schema note
            // ("null if attachment-only"), even though nothing produces an
            // attachment-only message yet — message_attachments itself isn't
            // built this feature (no reader/writer for it in a text-only
            // scope), unlike swipes/blocks/likes in earlier features which
            // had an immediate reader.
            $table->text('body')->nullable();
            $table->enum('type', ['text', 'voice_note', 'gif', 'photo'])->default('text');
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->index(['conversation_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('messages');
    }
};
