<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'email' => $this->email,
            'phone' => $this->phone,
            'status' => $this->status->value,
            'email_verified' => $this->email_verified_at !== null,
            'phone_verified' => $this->phone_verified_at !== null,
            'created_at' => $this->created_at,
        ];
    }
}
