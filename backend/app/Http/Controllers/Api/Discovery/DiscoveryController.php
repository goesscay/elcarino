<?php

namespace App\Http\Controllers\Api\Discovery;

use App\Http\Concerns\ResolvesDiscoveryContext;
use App\Http\Controllers\Controller;
use App\Http\Requests\Discovery\DiscoveryFeedRequest;
use App\Http\Resources\Discovery\DiscoveryCandidateResource;
use App\Services\Discovery\DiscoveryFeedService;
use Illuminate\Http\JsonResponse;

class DiscoveryController extends Controller
{
    use ResolvesDiscoveryContext;

    public function __construct(private readonly DiscoveryFeedService $feed) {}

    /**
     * GET /api/v1/discovery/feed
     */
    public function feed(DiscoveryFeedRequest $request): JsonResponse
    {
        $viewer = $request->user();

        $context = $this->discoveryContext($viewer);
        if ($context instanceof JsonResponse) {
            return $context;
        }
        [$location, $preferences] = $context;

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
