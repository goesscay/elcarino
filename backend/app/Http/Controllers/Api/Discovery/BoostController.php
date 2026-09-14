<?php

namespace App\Http\Controllers\Api\Discovery;

use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Services\Discovery\BoostService;
use App\Services\Discovery\BoostUnavailableException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BoostController extends Controller
{
    use RespondsWithErrorEnvelope;

    public function __construct(private readonly BoostService $boosts) {}

    /**
     * GET /api/v1/discovery/boost
     */
    public function status(Request $request): JsonResponse
    {
        return response()->json($this->boosts->status($request->user()));
    }

    /**
     * POST /api/v1/discovery/boost
     */
    public function store(Request $request): JsonResponse
    {
        try {
            $boost = $this->boosts->activate($request->user());
        } catch (BoostUnavailableException $e) {
            return $this->errorResponse($e->errorCode, $e->getMessage(), $e->httpStatus);
        }

        return response()->json([
            'starts_at' => $boost->starts_at->toIso8601String(),
            'ends_at' => $boost->ends_at->toIso8601String(),
        ], 201);
    }
}
