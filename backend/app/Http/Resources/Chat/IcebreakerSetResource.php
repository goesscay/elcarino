<?php

namespace App\Http\Resources\Chat;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A set of opening lines. `source` is `template` or `ai`, so the app can label
 * AI-written text as such (people should know when a machine wrote it).
 * Wraps the array `IcebreakerService::suggestions()` returns.
 */
class IcebreakerSetResource extends JsonResource
{
    /** The documented shape is flat (`{icebreakers, source}`), like the other chat endpoints. */
    public static $wrap = null;

    public function toArray(Request $request): array
    {
        return [
            'icebreakers' => $this->resource['lines'],
            'source' => $this->resource['source'],
        ];
    }
}
