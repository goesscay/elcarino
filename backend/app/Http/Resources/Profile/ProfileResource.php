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
            // Phase 2 item 2. Owner-only projection (`GET /profiles/me`) —
            // deliberately not added to any resource another user can fetch
            // (DiscoveryCandidateResource, MatchedUserResource): docs/07's
            // Profile detail screen spec doesn't list religion/politics as
            // shown content, and these are exactly the kind of personal
            // trait docs/06 §5 treats as sensitive. They exist server-side
            // purely so a filter has something to compare against.
            'religion' => $this->religion,
            'politics' => $this->politics,
            'is_verified' => $this->is_verified,
            'completion_pct' => $this->completion_pct,
            'photos' => ProfilePhotoResource::collection($this->whenLoaded('photos')),
        ];
    }
}
