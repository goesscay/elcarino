<?php

namespace App\Http\Resources\Subscriptions;

use App\Models\Subscription;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Subscription
 */
class SubscriptionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'status' => $this->status->value,
            'provider' => $this->provider->value,
            'started_at' => $this->started_at->toIso8601String(),
            'ends_at' => $this->ends_at->toIso8601String(),
            'plan' => new SubscriptionPlanResource($this->plan),
        ];
    }
}
