<?php

namespace App\Http\Controllers\Api\Profile;

use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Profile\ProfileUpdateRequest;
use App\Http\Resources\Profile\ProfileResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    use RespondsWithErrorEnvelope;

    /**
     * GET /api/v1/profiles/me
     */
    public function show(Request $request): JsonResponse
    {
        $profile = $request->user()->profile()->with('photos')->first();

        if (! $profile) {
            return $this->errorResponse('profile_not_found', 'Profile has not been created yet.', 404);
        }

        return response()->json(['profile' => new ProfileResource($profile)]);
    }

    /**
     * PUT /api/v1/profiles/me — onboarding's "Profile basics" step, and later
     * reused by Edit profile (Phase 1 item 3) — same endpoint, same contract.
     */
    public function update(ProfileUpdateRequest $request): JsonResponse
    {
        $profile = $request->user()->profile()->updateOrCreate([], $request->validated());
        $profile->recalculateCompletion();

        return response()->json(['profile' => new ProfileResource($profile->load('photos'))]);
    }
}
