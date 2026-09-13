<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\User\RegisterDeviceRequest;
use App\Http\Resources\UserDeviceResource;
use App\Models\UserDevice;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class UserDeviceController extends Controller
{
    /**
     * GET /api/v1/users/me/devices
     */
    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'devices' => UserDeviceResource::collection($request->user()->devices),
        ]);
    }

    /**
     * POST /api/v1/users/me/devices — register (or re-register) an FCM
     * token. `fcm_token` is unique across the whole table (docs/02), not
     * scoped to the caller — the same installation can log out and a
     * different account can log back in on it, at which point the token
     * should move to the new owner rather than fail as a duplicate or pile
     * up a second row nobody ever prunes.
     */
    public function store(RegisterDeviceRequest $request): JsonResponse
    {
        $device = UserDevice::query()->updateOrCreate(
            ['fcm_token' => $request->string('fcm_token')->toString()],
            [
                'user_id' => $request->user()->id,
                'platform' => $request->string('platform')->toString(),
                'app_version' => $request->input('app_version'),
                'last_seen_at' => now(),
            ],
        );

        return response()->json(['device' => new UserDeviceResource($device)], 201);
    }

    /**
     * DELETE /api/v1/users/me/devices/{device} — on logout/uninstall.
     */
    public function destroy(Request $request, UserDevice $device): JsonResponse
    {
        Gate::authorize('delete', $device);

        $device->delete();

        return response()->json(['message' => 'Device removed.']);
    }
}
