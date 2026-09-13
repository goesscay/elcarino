<?php

namespace App\Http\Resources;

use App\Models\UserDevice;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin UserDevice
 */
class UserDeviceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            // fcm_token deliberately omitted — the client already knows it
            // (it just registered it), no need to echo a token back.
            'platform' => $this->platform->value,
            'app_version' => $this->app_version,
            'last_seen_at' => $this->last_seen_at,
        ];
    }
}
