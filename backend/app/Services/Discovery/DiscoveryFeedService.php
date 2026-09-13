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
 * Phase 1 item 5's whole job: candidates matching the viewer's own filters
 * (age, distance, gender, relationship goal), excluding self/already-swiped/
 * blocked-either-direction. Mutual matching and interest-overlap scoring are
 * item 7 (Matching engine v1) — deliberately not here.
 *
 * Distance filtering/sorting happens in PHP after a bounded SQL prefetch
 * (config('discovery.candidate_scan_limit')), not a SQL geo query — see
 * config/discovery.php and docs/02's own "revisit only if it becomes a
 * bottleneck" note on geohash bucketing. Sorting is by *bucketed* distance,
 * never the raw float: docs/06 §4 explicitly forbids "sorting the feed by
 * exact distance in a way that lets a client binary-search a location."
 */
class DiscoveryFeedService
{
    /**
     * @return array{candidates: Collection<int, User>, hasMore: bool}
     */
    public function feed(User $viewer, UserLocation $viewerLocation, UserPreference $preferences, int $page, int $perPage): array
    {
        $excludedIds = $this->excludedUserIds($viewer);

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
            ])
            ->limit(config('discovery.candidate_scan_limit'))
            ->get();

        $withinRadius = $candidates
            ->map(function (User $candidate) use ($viewerLocation) {
                $km = Haversine::kilometers(
                    $viewerLocation->latitude,
                    $viewerLocation->longitude,
                    $candidate->location->latitude,
                    $candidate->location->longitude,
                );
                $candidate->setAttribute('distance_km', DistanceBucketer::bucketKm($km));
                $candidate->setAttribute('raw_distance_km', $km);

                return $candidate;
            })
            ->filter(fn (User $candidate) => $candidate->raw_distance_km <= $preferences->max_distance_km)
            // Sort by the *bucketed* value, not the raw float — see class doc.
            // id ASC is just a stable, non-precision-leaking tiebreaker so
            // pagination doesn't reshuffle between requests.
            ->sortBy([['distance_km', 'asc'], ['id', 'asc']])
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
