<?php

namespace App\Http\Controllers\Api\Profile;

use App\Http\Controllers\Controller;
use App\Http\Requests\Profile\InterestsUpdateRequest;
use App\Http\Resources\Profile\InterestResource;
use App\Models\Interest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InterestController extends Controller
{
    /**
     * GET /api/v1/interests — the full catalogue.
     */
    public function index(): JsonResponse
    {
        $interests = Interest::query()->orderBy('category')->orderBy('name')->get();

        return response()->json(['interests' => InterestResource::collection($interests)]);
    }

    /**
     * GET /api/v1/interests/me — the current user's selected interests.
     */
    public function mine(Request $request): JsonResponse
    {
        $interests = $request->user()->interests()->orderBy('name')->get();

        return response()->json(['interests' => InterestResource::collection($interests)]);
    }

    /**
     * PUT /api/v1/interests/me — full replace, same "upsert the whole set"
     * contract as prompts/preferences. A plain many-to-many with no extra
     * pivot columns, so sync() does exactly what's needed in one call.
     */
    public function update(InterestsUpdateRequest $request): JsonResponse
    {
        $request->user()->interests()->sync($request->input('interest_ids'));

        $interests = $request->user()->interests()->orderBy('name')->get();

        return response()->json(['interests' => InterestResource::collection($interests)]);
    }
}
