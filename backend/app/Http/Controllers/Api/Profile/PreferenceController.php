<?php

namespace App\Http\Controllers\Api\Profile;

use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Profile\PreferencesUpdateRequest;
use App\Http\Resources\Profile\PreferenceResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PreferenceController extends Controller
{
    use RespondsWithErrorEnvelope;

    /**
     * GET /api/v1/preferences/me
     */
    public function show(Request $request): JsonResponse
    {
        $preferences = $request->user()->preferences;

        if (! $preferences) {
            return $this->errorResponse('preferences_not_found', 'Preferences have not been set yet.', 404);
        }

        return response()->json(['preferences' => new PreferenceResource($preferences)]);
    }

    /**
     * PUT /api/v1/preferences/me
     */
    public function update(PreferencesUpdateRequest $request): JsonResponse
    {
        $preferences = $request->user()->preferences()->updateOrCreate([], $request->validated());
        $request->user()->profile?->recalculateCompletion();

        return response()->json(['preferences' => new PreferenceResource($preferences)]);
    }
}
