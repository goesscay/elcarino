<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // docs/02-database-schema.md "Verification", plus four columns the
        // doc's own "designed to support any of the three methods" claim
        // didn't cover (the doc is updated in the same commit): `pose` (the
        // server-issued liveness prompt the selfie must show), `selfie_path`
        // (the encrypted upload, nulled the moment a decision is made —
        // docs/06 §5 "shortest viable retention"), and `ai_outcome`/
        // `ai_score` (what the matcher said, kept so a human reviewer sees why
        // a request landed in their queue).
        Schema::create('verification_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('method', ['ai_selfie', 'manual_review', 'id_document'])->default('ai_selfie');
            $table->enum('status', ['pending', 'processing', 'approved', 'rejected'])->default('processing');
            $table->string('pose', 40);
            $table->string('selfie_path')->nullable();
            $table->string('ai_outcome', 30)->nullable();
            $table->float('ai_score')->nullable();
            $table->timestamp('submitted_at');
            $table->timestamps();

            $table->index(['user_id', 'status']);
            $table->index(['status', 'method']);
        });

        Schema::create('verification_results', function (Blueprint $table) {
            $table->id();
            $table->foreignId('verification_request_id')->constrained('verification_requests')->cascadeOnDelete();
            $table->enum('decided_by', ['ai', 'admin']);
            $table->float('confidence_score')->nullable();
            $table->foreignId('reviewer_id')->nullable()->constrained('users')->nullOnDelete();
            // Why it was rejected (a code, e.g. no_face_detected) — null on approval.
            $table->string('reason', 40)->nullable();
            $table->timestamp('decided_at');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('verification_results');
        Schema::dropIfExists('verification_requests');
    }
};
