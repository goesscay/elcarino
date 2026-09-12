<?php

namespace App\Http\Concerns;

use Illuminate\Http\JsonResponse;

/**
 * The business-rule error shape from docs/03-api-specification.md's
 * cross-cutting standards — distinct from Laravel's automatic 422 validation
 * envelope. See that doc for why the two are deliberately different shapes.
 */
trait RespondsWithErrorEnvelope
{
    private function errorResponse(string $code, string $message, int $status): JsonResponse
    {
        return response()->json(['error' => ['code' => $code, 'message' => $message]], $status);
    }
}
