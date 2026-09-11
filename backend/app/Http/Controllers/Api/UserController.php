<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
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
}
