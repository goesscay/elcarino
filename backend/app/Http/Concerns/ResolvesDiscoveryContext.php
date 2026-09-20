<?php

namespace App\Http\Concerns;

use App\Models\User;
use App\Models\UserLocation;
use App\Models\UserPreference;
use Illuminate\Http\JsonResponse;

/**
 * What every "who could I be shown" endpoint needs from the viewer before it
 * can answer: a stored location and saved preferences. Missing either is a
 * 422 with a code the mobile app turns into "go set that first" guidance
 * (docs/03 Discovery), the same for the feed and for Explore.
 */
trait ResolvesDiscoveryContext
{
    use RespondsWithErrorEnvelope;

    /**
     * @return array{0: UserLocation, 1: UserPreference}|JsonResponse
     */
    private function discoveryContext(User $viewer): array|JsonResponse
    {
        $location = $viewer->location;
        if (! $location) {
            return $this->errorResponse(
                'location_required',
                'Set your location before viewing the discovery feed.',
                422,
            );
        }

        $preferences = $viewer->preferences;
        if (! $preferences) {
            return $this->errorResponse(
                'preferences_required',
                'Set your discovery preferences before viewing the discovery feed.',
                422,
            );
        }

        return [$location, $preferences];
    }
}
