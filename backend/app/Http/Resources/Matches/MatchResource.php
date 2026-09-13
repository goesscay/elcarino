<?php

namespace App\Http\Resources\Matches;

use App\Models\UserMatch;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin UserMatch
 */
class MatchResource extends JsonResource
{
    public function __construct(UserMatch $resource, private readonly int $viewerId)
    {
        parent::__construct($resource);
    }

    public function toArray(Request $request): array
    {
        $otherUser = $this->user_one_id === $this->viewerId ? $this->userTwo : $this->userOne;

        return [
            'id' => $this->id,
            'other_user' => new MatchedUserResource($otherUser),
            'matched_at' => $this->matched_at,
            'unmatched_at' => $this->unmatched_at,
        ];
    }
}
