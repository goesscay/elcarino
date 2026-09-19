<?php

namespace App\Http\Controllers\Api\Likes;

use App\Http\Controllers\Controller;
use App\Http\Requests\Discovery\DiscoveryFeedRequest;
use App\Http\Resources\Discovery\DiscoveryCandidateResource;
use App\Services\Likes\LikesService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;

class LikesController extends Controller
{
    public function __construct(private readonly LikesService $likes) {}

    /**
     * GET /api/v1/likes/received
     *
     * Who liked me (docs/07 §3.4). A non-subscriber gets the *count* and
     * `locked: true` and nothing else — no user is loaded, so there's no
     * identity, photo or id in the response to blur client-side or scrape.
     */
    public function received(DiscoveryFeedRequest $request): JsonResponse
    {
        $viewer = $request->user();
        $total = $this->likes->receivedCount($viewer);

        if (! Gate::forUser($viewer)->allows('view-who-liked-me')) {
            return response()->json([
                'locked' => true,
                'total' => $total,
                'likes' => [],
                'meta' => ['page' => 1, 'per_page' => $request->perPage(), 'has_more' => false],
            ]);
        }

        $result = $this->likes->received($viewer, $request->page(), $request->perPage());

        return response()->json([
            'locked' => false,
            'total' => $total,
            'likes' => DiscoveryCandidateResource::collection($result['users']),
            'meta' => [
                'page' => $request->page(),
                'per_page' => $request->perPage(),
                'has_more' => $result['hasMore'],
            ],
        ]);
    }

    /**
     * GET /api/v1/likes/sent — people I liked who haven't matched with me.
     * Free for everyone: these are the viewer's own actions.
     */
    public function sent(DiscoveryFeedRequest $request): JsonResponse
    {
        $viewer = $request->user();
        $result = $this->likes->sent($viewer, $request->page(), $request->perPage());

        return response()->json([
            'total' => $this->likes->sentCount($viewer),
            'likes' => DiscoveryCandidateResource::collection($result['users']),
            'meta' => [
                'page' => $request->page(),
                'per_page' => $request->perPage(),
                'has_more' => $result['hasMore'],
            ],
        ]);
    }
}
