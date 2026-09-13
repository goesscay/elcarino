<?php

namespace App\Http\Controllers\Api\Safety;

use App\Enums\ReportCategory;
use App\Http\Controllers\Controller;
use App\Http\Requests\Safety\BlockRequest;
use App\Http\Requests\Safety\ReportRequest;
use App\Http\Resources\Safety\BlockedUserResource;
use App\Models\Block;
use App\Models\Report;
use App\Models\User;
use App\Services\Safety\SafetyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class SafetyController extends Controller
{
    public function __construct(private readonly SafetyService $safety) {}

    /**
     * GET /api/v1/safety/blocks — docs/07 §3.7 "Blocked users" Settings
     * child screen. Not in docs/03's original endpoint table — added here,
     * in the same commit that builds the screen it feeds.
     */
    public function blocks(Request $request): JsonResponse
    {
        $blocked = $request->user()->blocksMade()->with('blocked.profile.photos')->get()
            ->map(fn (Block $block) => $block->blocked);

        return response()->json(['blocked_users' => BlockedUserResource::collection($blocked)]);
    }

    /**
     * POST /api/v1/safety/block
     */
    public function block(BlockRequest $request): JsonResponse
    {
        $target = User::query()->findOrFail($request->integer('user_id'));

        Gate::authorize('create', [Block::class, $target]);

        $this->safety->block($request->user(), $target);

        return response()->json(['message' => 'Blocked.'], 201);
    }

    /**
     * DELETE /api/v1/safety/block/{userId} — scoped to the caller's own
     * blocks via the blocksMade() relation, so there's nothing to
     * authorize beyond that; idempotent either way (see SafetyService).
     */
    public function unblock(Request $request, int $userId): JsonResponse
    {
        $this->safety->unblock($request->user(), $userId);

        return response()->json(['message' => 'Unblocked.']);
    }

    /**
     * POST /api/v1/safety/report
     */
    public function report(ReportRequest $request): JsonResponse
    {
        $target = User::query()->findOrFail($request->integer('user_id'));

        Gate::authorize('create', [Report::class, $target]);

        $this->safety->report(
            $request->user(),
            $target,
            $request->enum('category', ReportCategory::class),
            $request->input('description'),
            $request->boolean('also_block'),
        );

        return response()->json(['message' => 'Thanks — our team will review this.'], 201);
    }

    /**
     * GET /api/v1/safety/report-categories — docs/03 says "public"; kept
     * behind auth like every other route in this group for now, same
     * reasoning as PromptController::index's library endpoint.
     */
    public function reportCategories(): JsonResponse
    {
        return response()->json([
            'categories' => array_map(fn (ReportCategory $c) => $c->value, ReportCategory::cases()),
        ]);
    }
}
