<?php

namespace App\Http\Controllers\Api\Discovery;

use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Discovery\DiscoveryFeedRequest;
use App\Http\Resources\Discovery\DiscoveryCandidateResource;
use App\Services\Discovery\DiscoveryFeedService;
use Illuminate\Http\JsonResponse;

class DiscoveryController extends Controller
{
    use RespondsWithErrorEnvelope;

    public function __construct(private readonly DiscoveryFeedService $feed) {}

    /**
     * GET /api/v1/discovery/feed
     */
    public function feed(DiscoveryFeedRequest $request): JsonResponse
    {
        $viewer = $request->user();

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

        $result = $this->feed->feed(
            $viewer,
            $location,
            $preferences,
            $request->page(),
            $request->perPage(),
        );

        return response()->json([
            'candidates' => DiscoveryCandidateResource::collection($result['candidates']),
            'meta' => [
                'page' => $request->page(),
                'per_page' => $request->perPage(),
                'has_more' => $result['hasMore'],
            ],
        ]);
    }
}
