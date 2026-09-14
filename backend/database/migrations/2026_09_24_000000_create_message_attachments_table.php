<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * docs/02-database-schema.md `message_attachments` — schema-only since
     * Phase 1 item 8 ("no reader/writer for it in a text-only scope").
     * Phase 3's first item: voice notes (open decision #16, working
     * assumption "in scope pending confirmation" — unlike Phase 2's Super
     * Like/Rewind, this one's stated default is to build it, not wait).
     *
     * `message_id` unique: docs/02 doesn't say a message can have more than
     * one attachment, and nothing in this feature (or docs/07's composer
     * spec — one attachment type picked at a time) ever creates more than
     * one per message. A real constraint, not just an assumption left
     * unenforced.
     */
    public function up(): void
    {
        Schema::create('message_attachments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('message_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('storage_path');
            $table->string('mime_type');
            $table->smallInteger('duration_seconds')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('message_attachments');
    }
};
