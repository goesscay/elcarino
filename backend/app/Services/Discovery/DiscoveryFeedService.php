<?php

namespace App\Services\Discovery;

use App\Models\Block;
use App\Models\Swipe;
use App\Models\User;
use App\Models\UserLocation;
use App\Models\UserPreference;
use App\Services\Geo\Haversine;
use Illuminate\Support\Collection;

/**
 * Phase 1 items 5 + 7's combined job. Item 5: candidates matching the
 * viewer's own filters (age, distance, gender, relationship goal), excluding
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
    /**
     * @return array{candidates: Collection<int, User>, hasMore: bool}
     */
    public function feed(User $viewer, UserLocation $viewerLocation, UserPreference $preferences, int $page, int $perPage): array
    {
        $excludedIds = $this->excludedUserIds($viewer);
        $viewerInterestIds = $viewer->interests()->pluck('interests.id');

        $today = now();
        $maxBirthDate = $today->copy()->subYears($preferences->min_age);
        $minBirthDate = $today->copy()->subYears($preferences->max_age + 1)->addDay();

        $candidates = User::query()
            ->whereNotIn('id', $excludedIds)
            ->whereHas('profile', function ($query) use ($preferences, $maxBirthDate, $minBirthDate) {
                $query->whereIn('gender', $preferences->interested_in_genders)
                    ->whereDate('birth_date', '<=', $maxBirthDate)
                    ->whereDate('birth_date', '>=', $minBirthDate)
                    ->whereHas('photos');

                if (! empty($preferences->relationship_goal_filter)) {
                    $query->whereIn('relationship_goal', $preferences->relationship_goal_filter);
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

        $withinRadius = $candidates
            ->map(function (User $candidate) use ($viewerLocation, $viewerInterestIds) {
                $km = Haversine::kilometers(
                    $viewerLocation->latitude,
                    $viewerLocation->longitude,
                    $candidate->location->latitude,
                    $candidate->location->longitude,
                );
                $candidate->setAttribute('distance_km', DistanceBucketer::bucketKm($km));
                $candidate->setAttribute('raw_distance_km', $km);

                $shared = $candidate->interests->whereIn('id', $viewerInterestIds);
                $candidate->setAttribute('shared_interests_count', $shared->count());
                $candidate->setAttribute('shared_interest_names', $shared->pluck('name')->values());

                return $candidate;
            })
            ->filter(fn (User $candidate) => $candidate->raw_distance_km <= $preferences->max_distance_km)
            // Rule-based ranking (item 7): more shared interests first, then
            // nearer (bucketed) first, then id as a stable, non-leaking
            // tiebreaker so pagination doesn't reshuffle between requests —
            // never the raw distance float, see class doc.
            ->sortBy([['shared_interests_count', 'desc'], ['distance_km', 'asc'], ['id', 'asc']])
            ->values();

        $paged = $withinRadius->slice(($page - 1) * $perPage, $perPage)->values();

        return [
            'candidates' => $paged,
            'hasMore' => $withinRadius->count() > $page * $perPage,
        ];
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
