<?php

namespace App\Http\Controllers\Api\Matches;

use App\Http\Controllers\Controller;
use App\Http\Resources\Matches\MatchResource;
use App\Models\UserMatch;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class MatchController extends Controller
{
    /**
     * GET /api/v1/matches — active matches only, most recent first.
     */
    public function index(Request $request): JsonResponse
    {
        $viewer = $request->user();

        $matches = UserMatch::query()
            ->where(fn ($q) => $q->where('user_one_id', $viewer->id)->orWhere('user_two_id', $viewer->id))
            ->whereNull('unmatched_at')
            ->with(['userOne.profile.photos', 'userTwo.profile.photos'])
            ->orderByDesc('matched_at')
            ->get();

        return response()->json([
            'matches' => $matches->map(fn (UserMatch $match) => new MatchResource($match, $viewer->id)),
        ]);
    }

    /**
     * GET /api/v1/matches/{match}
     */
    public function show(Request $request, UserMatch $match): JsonResponse
    {
        Gate::authorize('view', $match);

        $match->load(['userOne.profile.photos', 'userTwo.profile.photos']);

        return response()->json(['match' => new MatchResource($match, $request->user()->id)]);
    }

    /**
     * DELETE /api/v1/matches/{match} — unmatch. Soft: sets unmatched_at/by
     * rather than deleting the row (docs/02-database-schema.md).
     */
    public function destroy(Request $request, UserMatch $match): JsonResponse
    {
        Gate::authorize('delete', $match);

        $match->forceFill([
            'unmatched_at' => now(),
            'unmatched_by' => $request->user()->id,
        ])->save();

        return response()->json(['message' => 'Unmatched.']);
    }
}
