<?php

namespace App\Http\Resources\Profile;

use App\Models\UserPreference;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin UserPreference
 */
class PreferenceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'min_age' => $this->min_age,
            'max_age' => $this->max_age,
            'max_distance_km' => $this->max_distance_km,
            'interested_in_genders' => $this->interested_in_genders,
            'religion_filter' => $this->religion_filter,
            'politics_filter' => $this->politics_filter,
            'relationship_goal_filter' => $this->relationship_goal_filter,
        ];
    }
}
