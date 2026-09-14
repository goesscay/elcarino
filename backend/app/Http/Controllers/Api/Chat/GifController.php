<?php

namespace App\Http\Controllers\Api\Chat;

use App\Http\Controllers\Controller;
use App\Http\Requests\Chat\GifSearchRequest;
use App\Http\Resources\Chat\GifResultResource;
use App\Services\Gifs\GifProvider;
use Illuminate\Http\JsonResponse;

class GifController extends Controller
{
    public function __construct(private readonly GifProvider $gifs) {}

    /**
     * GET /api/v1/gifs/search — Phase 3 item 2 (open decision #17). The
     * chat composer's GIF picker searches through this endpoint rather than
     * the mobile app calling Giphy directly, so the API key stays
     * server-side (never shipped in the client) and so the provider can be
     * swapped (GifProvider) without a mobile release.
     */
    public function search(GifSearchRequest $request): JsonResponse
    {
        $result = $this->gifs->search(
            $request->string('q')->toString(),
            $request->integer('page', 1),
        );

        return response()->json([
            'gifs' => GifResultResource::collection($result->items),
            'meta' => ['has_more' => $result->hasMore],
        ]);
    }
}
