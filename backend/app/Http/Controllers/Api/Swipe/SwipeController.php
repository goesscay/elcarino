<?php

namespace App\Http\Controllers\Api\Swipe;

use App\Enums\SwipeDirection;
use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Swipe\SwipeRequest;
use App\Models\Swipe;
use App\Models\User;
use App\Services\Matching\AlreadySwipedException;
use App\Services\Matching\SwipeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;

class SwipeController extends Controller
{
    use RespondsWithErrorEnvelope;

    public function __construct(private readonly SwipeService $swipes) {}

    /**
     * POST /api/v1/swipes
     */
    public function store(SwipeRequest $request): JsonResponse
    {
        $target = User::query()->findOrFail($request->integer('target_id'));

        Gate::authorize('create', [Swipe::class, $target]);

        try {
            $result = $this->swipes->recordSwipe(
                $request->user(),
                $target,
                $request->enum('direction', SwipeDirection::class),
            );
        } catch (AlreadySwipedException $e) {
            return $this->errorResponse('already_swiped', $e->getMessage(), 422);
        }

        return response()->json([
            'matched' => $result['match'] !== null,
            'match_id' => $result['match']?->id,
        ], 201);
    }
}
