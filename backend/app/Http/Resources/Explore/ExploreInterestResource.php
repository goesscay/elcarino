<?php

namespace App\Http\Resources\Explore;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One Explore tile: an interest plus how many eligible people share it.
 * Wraps the array `ExploreService::interests()` returns.
 */
class ExploreInterestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->resource['interest']->id,
            'name' => $this->resource['interest']->name,
            'category' => $this->resource['interest']->category,
            'member_count' => $this->resource['member_count'],
            'is_yours' => $this->resource['is_yours'],
        ];
    }
}
