<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * docs/01-technical-specification.md §8: "Advanced filters [REQUIRED]:
     * religion, politics ... build these as filterable fields on
     * user_preferences, not as an afterthought." `user_preferences` already
     * had `religion_filter`/`politics_filter` (Phase 1 item 5) — what a
     * viewer wants to filter *by* — but nothing on `profiles` for a
     * candidate to actually *have*, so the filter was structurally
     * unusable. Free-form strings, not an enum: same reasoning as the
     * filter columns themselves (no value taxonomy is defined anywhere in
     * /docs — see PreferencesUpdateRequest's own note). Not in docs/02's
     * original `profiles` table — added there in this commit.
     */
    public function up(): void
    {
        Schema::table('profiles', function (Blueprint $table) {
            $table->string('religion')->nullable()->after('relationship_goal');
            $table->string('politics')->nullable()->after('religion');
        });
    }

    public function down(): void
    {
        Schema::table('profiles', function (Blueprint $table) {
            $table->dropColumn(['religion', 'politics']);
        });
    }
};
