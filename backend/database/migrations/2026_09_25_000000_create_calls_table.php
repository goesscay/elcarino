<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * docs/02-database-schema.md `calls` — new with Phase 3 items 4/5 (voice
     * + video calling, open decisions #19/#20, confirmed WebRTC). Not
     * pre-speced the way `message_attachments` was — spec §13 was
     * `[PROPOSED]` with the provider itself unconfirmed until now, so
     * there was nothing concrete to design a schema against earlier.
     *
     * `caller_id`/`callee_id` are stored directly (not just derived from
     * `conversation_id` + who's who) so "who called whom" is a plain
     * column, not a runtime lookup, for analytics/support (docs/04's gate:
     * "call minutes are logged for support/analytics").
     *
     * `duration_seconds` is stored at end time rather than computed on
     * every read from `started_at`/`ended_at` — a support query ("how long
     * was this call") shouldn't need date-math, same reasoning as
     * `message_attachments.duration_seconds` for voice notes. Null until
     * the call actually connects (`started_at` set) and ends.
     */
    public function up(): void
    {
        Schema::create('calls', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained()->cascadeOnDelete();
            $table->foreignId('caller_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('callee_id')->constrained('users')->cascadeOnDelete();
            $table->enum('type', ['voice', 'video']);
            // ringing: created, not yet answered. active: callee answered,
            // in progress. ended: hung up normally after connecting.
            // missed: caller ended/it timed out before the callee answered.
            // declined: callee explicitly rejected it. failed: reserved for
            // a client-reported ICE/connection failure — not written by any
            // code yet (disclosed: no ICE-failure reporting endpoint exists
            // this pass), kept in the enum now for the same "no migration
            // needed later" reason as MessageType's unused cases originally.
            $table->enum('status', ['ringing', 'active', 'ended', 'missed', 'declined', 'failed'])
                ->default('ringing');
            $table->timestamp('started_at')->nullable();
            $table->timestamp('ended_at')->nullable();
            $table->foreignId('ended_by')->nullable()->constrained('users')->nullOnDelete();
            $table->smallInteger('duration_seconds')->nullable();
            $table->timestamps();

            $table->index(['conversation_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('calls');
    }
};
