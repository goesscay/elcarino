<?php

namespace App\Services\Discovery;

use App\Models\User;
use App\Models\UserLocation;
use App\Services\Geo\Haversine;
use Illuminate\Support\Collection;

/**
 * Sets the viewer-relative fields `DiscoveryCandidateResource` serialises
 * (`distance_km`, `shared_interests_count`, `shared_interest_names`) onto a
 * batch of users. Shared by the discovery feed, "who liked me"/"people you
 * like" and Explore, so all three describe a person identically and none of
 * them can leak a raw distance (docs/06 §4): `distance_km` is always the
 * bucketed value, and `raw_distance_km` exists only for the caller's own
 * filtering/sorting and is never serialised.
 *
 * `distance_km` is null when either side has no stored location — only
 * reachable outside the feed (the feed already requires a location on both
 * ends), e.g. a liker who never shared theirs.
 */
class CandidateAnnotator
{
    /**
     * @param  Collection<int, User>  $users  with `location` and `interests` loaded
     * @param  Collection<int, int>  $viewerInterestIds
     * @return Collection<int, User>
     */
    public function annotate(Collection $users, ?UserLocation $viewerLocation, Collection $viewerInterestIds): Collection
    {
        return $users->map(function (User $user) use ($viewerLocation, $viewerInterestIds) {
            $km = ($viewerLocation && $user->location)
                ? Haversine::kilometers(
                    $viewerLocation->latitude,
                    $viewerLocation->longitude,
                    $user->location->latitude,
                    $user->location->longitude,
                )
                : null;

            $user->setAttribute('distance_km', $km === null ? null : DistanceBucketer::bucketKm($km));
            $user->setAttribute('raw_distance_km', $km);

            $shared = $user->interests->whereIn('id', $viewerInterestIds);
            $user->setAttribute('shared_interests_count', $shared->count());
            $user->setAttribute('shared_interest_names', $shared->pluck('name')->values());

            return $user;
        });
    }
}
