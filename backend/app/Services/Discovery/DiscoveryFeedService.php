<?php

namespace App\Services\Discovery;

use App\Enums\UserStatus;
use App\Models\Block;
use App\Models\Boost;
use App\Models\Swipe;
use App\Models\User;
use App\Models\UserLocation;
use App\Models\UserPreference;
use Illuminate\Support\Collection;

/**
 * Phase 1 items 5 + 7, plus Phase 2 item 3's boost ranking, combined.
 * Item 5: candidates matching the viewer's own filters (age, distance,
 * gender, relationship goal), excluding
 * self/already-swiped/blocked-either-direction. Item 7 (Matching engine v1)
 * adds the ranking on top: "rule-based — preferences + interests overlap"
 * per docs/04-development-phases.md, deliberately **not** a compatibility
 * score. docs/01-technical-specification.md §10 is explicit: "do not
 * hardcode a scoring algorithm in Phase 1; stub the field and revisit in
 * Phase 4" — a weighted formula blending multiple signals into one opaque
 * number is exactly what that forbids. What's here instead is a single,
 * transparent, explainable count (shared interests), used only as a sort
 * key and returned in the response as-is — never turned into a percentage
 * or a hidden score. "User behaviour" (also named in spec §10) isn't
 * implemented — the spec doesn't say what signal or algorithm that would
 * even mean, and inventing one would be exactly the kind of unstated
 * specific CLAUDE.md says to flag, not guess at.
 *
 * Distance filtering/sorting happens in PHP after a bounded SQL prefetch
 * (config('discovery.candidate_scan_limit')), not a SQL geo query — see
 * config/discovery.php and docs/02's own "revisit only if it becomes a
 * bottleneck" note on geohash bucketing. Distance is always sorted by its
 * *bucketed* value, never the raw float: docs/06 §4 explicitly forbids
 * "sorting the feed by exact distance in a way that lets a client
 * binary-search a location."
 */
class DiscoveryFeedService
{
    public function __construct(private readonly CandidateAnnotator $annotator) {}

    /**
     * @return array{candidates: Collection<int, User>, hasMore: bool}
     */
    public function feed(User $viewer, UserLocation $viewerLocation, UserPreference $preferences, int $page, int $perPage): array
    {
        $eligible = $this->eligible($viewer, $viewerLocation, $preferences);

        return [
            'candidates' => $eligible->slice(($page - 1) * $perPage, $perPage)->values(),
            'hasMore' => $eligible->count() > $page * $perPage,
        ];
    }

    /**
     * Everyone the viewer could be shown right now, annotated and ranked — the
     * feed's whole result before it's paginated. Explore reads the same set, so
     * a person it lists is always someone the Discover deck could also show
     * (same filters, distance, exclusions and order), and never someone the
     * viewer has already swiped on.
     *
     * Bounded by `discovery.candidate_scan_limit`, so on a large user base this
     * is "the best N within reach", not everyone.
     *
     * @return Collection<int, User>
     */
    public function eligible(User $viewer, UserLocation $viewerLocation, UserPreference $preferences): Collection
    {
        $excludedIds = $this->excludedUserIds($viewer);
        $viewerInterestIds = $viewer->interests()->pluck('interests.id');

        $today = now();
        $maxBirthDate = $today->copy()->subYears($preferences->min_age);
        $minBirthDate = $today->copy()->subYears($preferences->max_age + 1)->addDay();

        $candidates = User::query()
            // Admin-suspended/banned accounts (Phase 1 item 11, docs/06 §9)
            // must disappear from discovery immediately — soft-deleted
            // ("deleted" status) accounts are already excluded for free by
            // Eloquent's SoftDeletes global scope, but suspended/banned
            // rows are still very much present, just status-flagged.
            ->where('status', UserStatus::Active)
            ->whereNotIn('id', $excludedIds)
            ->whereHas('profile', function ($query) use ($viewer, $preferences, $maxBirthDate, $minBirthDate) {
                $query->whereIn('gender', $preferences->interested_in_genders)
                    ->whereDate('birth_date', '<=', $maxBirthDate)
                    ->whereDate('birth_date', '>=', $minBirthDate)
                    ->whereHas('photos');

                if (! empty($preferences->relationship_goal_filter)) {
                    $query->whereIn('relationship_goal', $preferences->relationship_goal_filter);
                }

                // Phase 2 item 2 (docs/01 §8 "Advanced filters", docs/06 §3.4):
                // gated at read time regardless of what's stored on
                // `preferences` — the authoritative check, not just
                // PreferenceController's write-time one. A lapsed
                // subscriber's still-stored religion_filter/politics_filter
                // never narrows their feed once entitlement() goes false.
                // `whereIn` never matches a NULL column, so a candidate who
                // hasn't stated their own religion/politics is correctly
                // excluded rather than treated as a wildcard match.
                if ($viewer->entitlement('advanced_filters')) {
                    if (! empty($preferences->religion_filter)) {
                        $query->whereIn('religion', $preferences->religion_filter);
                    }
                    if (! empty($preferences->politics_filter)) {
                        $query->whereIn('politics', $preferences->politics_filter);
                    }
                }
            })
            ->whereHas('location')
            ->with([
                'profile.photos' => fn ($query) => $query->where('moderation_status', 'approved')->orderBy('sort_order'),
                'location',
                'profilePrompts.prompt',
                'interests',
            ])
            ->limit(config('discovery.candidate_scan_limit'))
            ->get();

        // Phase 2 item 3 / open decision #14's "visibility window" boost
        // mechanic: a currently-active boost moves a candidate to the front
        // of the queue. One bulk query for the whole scanned batch, not one
        // per candidate.
        $boostedUserIds = Boost::query()
            ->whereIn('user_id', $candidates->pluck('id'))
            ->where('starts_at', '<=', $today)
            ->where('ends_at', '>', $today)
            ->pluck('user_id')
            ->all();

        $withinRadius = $this->annotator
            ->annotate($candidates, $viewerLocation, $viewerInterestIds)
            ->each(fn (User $candidate) => $candidate->setAttribute(
                'is_boosted',
                in_array($candidate->id, $boostedUserIds, true),
            ))
            ->filter(fn (User $candidate) => $candidate->raw_distance_km <= $preferences->max_distance_km)
            // Rule-based ranking (item 7): boosted first (item 3), then more
            // shared interests, then nearer (bucketed), then id as a stable,
            // non-leaking tiebreaker so pagination doesn't reshuffle between
            // requests — never the raw distance float, see class doc.
            ->sortBy([['is_boosted', 'desc'], ['shared_interests_count', 'desc'], ['distance_km', 'asc'], ['id', 'asc']])
            ->values();

        return $withinRadius;
    }

    /**
     * @return Collection<int, int>
     */
    private function excludedUserIds(User $viewer): Collection
    {
        return collect([$viewer->id])
            ->merge(Swipe::query()->where('actor_id', $viewer->id)->pluck('target_id'))
            ->merge(Block::query()->where('blocker_id', $viewer->id)->pluck('blocked_id'))
            ->merge(Block::query()->where('blocked_id', $viewer->id)->pluck('blocker_id'))
            ->unique()
            ->values();
    }
}
