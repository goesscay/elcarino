<?php

namespace App\Http\Resources\Discovery;

use App\Http\Resources\Profile\ProfilePhotoResource;
use App\Http\Resources\Profile\UserProfilePromptResource;
use App\Models\Profile;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The "public profile projection" for a discovery candidate — deliberately
 * narrower than ProfileResource: no raw coordinates (docs/06 §4, never), no
 * `completion_pct` (only meaningful to the owner). `distance_km` and
 * `shared_interests_count`/`shared_interests` are set onto the model by
 * DiscoveryFeedService before this resource wraps it — see DistanceBucketer
 * and that service's class doc (item 7 — a plain, transparent count, not a
 * compatibility score) for what each one means.
 *
 * @mixin User
 */
class DiscoveryCandidateResource extends JsonResource
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
            'relationship_goal' => $profile->relationship_goal,
            'is_verified' => $profile->is_verified,
            'distance_km' => $this->distance_km,
            'shared_interests_count' => $this->shared_interests_count,
            'shared_interests' => $this->shared_interest_names,
            'photos' => ProfilePhotoResource::collection($profile->photos),
            'prompts' => UserProfilePromptResource::collection($this->profilePrompts),
        ];
    }
}
