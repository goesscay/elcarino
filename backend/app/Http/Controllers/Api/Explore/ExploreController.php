<?php

namespace App\Http\Controllers\Api\Explore;

use App\Http\Concerns\ResolvesDiscoveryContext;
use App\Http\Controllers\Controller;
use App\Http\Requests\Discovery\DiscoveryFeedRequest;
use App\Http\Resources\Discovery\DiscoveryCandidateResource;
use App\Http\Resources\Explore\ExploreInterestResource;
use App\Models\Interest;
use App\Services\Explore\ExploreService;
use Illuminate\Http\JsonResponse;

class ExploreController extends Controller
{
    use ResolvesDiscoveryContext;

    public function __construct(private readonly ExploreService $explore) {}

    /**
     * GET /api/v1/explore/interests
     */
    public function interests(DiscoveryFeedRequest $request): JsonResponse
    {
        $viewer = $request->user();
        $context = $this->discoveryContext($viewer);
        if ($context instanceof JsonResponse) {
            return $context;
        }
        [$location, $preferences] = $context;

        return response()->json([
            'interests' => ExploreInterestResource::collection(
                $this->explore->interests($viewer, $location, $preferences),
            ),
        ]);
    }

    /**
     * GET /api/v1/explore/interests/{interest}/people
     */
    public function people(DiscoveryFeedRequest $request, Interest $interest): JsonResponse
    {
        $viewer = $request->user();
        $context = $this->discoveryContext($viewer);
        if ($context instanceof JsonResponse) {
            return $context;
        }
        [$location, $preferences] = $context;

        $result = $this->explore->people(
            $viewer,
            $location,
            $preferences,
            $interest,
            $request->page(),
            $request->perPage(),
        );

        return response()->json([
            'interest' => ['id' => $interest->id, 'name' => $interest->name, 'category' => $interest->category],
            'total' => $result['total'],
            'people' => DiscoveryCandidateResource::collection($result['people']),
            'meta' => [
                'page' => $request->page(),
                'per_page' => $request->perPage(),
                'has_more' => $result['hasMore'],
            ],
        ]);
    }
}
