<?php

namespace App\Http\Resources\Matches;

use App\Http\Resources\Profile\ProfilePhotoResource;
use App\Models\Profile;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The other participant's public profile projection inside a match — like
 * DiscoveryCandidateResource, but no `distance_km` (matches aren't
 * distance-scoped).
 *
 * @mixin User
 */
class MatchedUserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        /** @var Profile $profile */
        $profile = $this->profile;

        return [
            'id' => $this->id,
            'display_name' => $profile->display_name,
            'age' => $profile->birth_date->age,
            'bio' => $profile->bio,
            'is_verified' => $profile->is_verified,
            'photos' => ProfilePhotoResource::collection($profile->photos),
        ];
    }
}
