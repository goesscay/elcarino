<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\User\UpdateLocationRequest;
use App\Http\Resources\UserResource;
use App\Models\UserLocation;
use App\Services\Geo\Geohash;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserController extends Controller
{
    /**
     * GET /api/v1/users/me — smoke-tests that Sanctum auth works end to end;
     * the rest of the Users resource group lands with the Profile feature.
     */
    public function me(Request $request): UserResource
    {
        return new UserResource($request->user());
    }

    /**
     * PUT /api/v1/users/me/location — feeds the discovery feed (Phase 1 item
     * 5). Never echoes the coordinates back (docs/06 §4/§5 — exact
     * coordinates are "Critical" data); the caller already knows what it
     * sent. Rounded to 3 decimal places (~100 m) server-side as
     * defense-in-depth even though the client is also expected to send
     * coarse coordinates already (docs/06 §4) — never rely on client-only
     * enforcement of a stated privacy invariant.
     */
    public function updateLocation(UpdateLocationRequest $request): JsonResponse
    {
        $latitude = round((float) $request->input('latitude'), 3);
        $longitude = round((float) $request->input('longitude'), 3);

        UserLocation::query()->updateOrCreate(
            ['user_id' => $request->user()->id],
            [
                'latitude' => $latitude,
                'longitude' => $longitude,
                'geohash' => Geohash::encode($latitude, $longitude),
            ],
        );

        return response()->json(['message' => 'Location updated.']);
    }
}
