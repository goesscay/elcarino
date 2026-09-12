<?php

namespace App\Http\Resources\Profile;

use App\Models\Profile;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Profile
 */
class ProfileResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'display_name' => $this->display_name,
            'birth_date' => $this->birth_date->toDateString(),
            'gender' => $this->gender->value,
            'bio' => $this->bio,
            'relationship_goal' => $this->relationship_goal,
            'is_verified' => $this->is_verified,
            'completion_pct' => $this->completion_pct,
            'photos' => ProfilePhotoResource::collection($this->whenLoaded('photos')),
        ];
    }
}
