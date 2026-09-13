<?php

namespace App\Http\Resources\Notifications;

use App\Models\Notification;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Notification
 */
class NotificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type->value,
            'payload' => $this->payload,
            'read_at' => $this->read_at,
            'created_at' => $this->created_at,
        ];
    }
}
