<?php

namespace App\Http\Resources\Calls;

use App\Http\Resources\Matches\MatchedUserResource;
use App\Models\Call;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Call
 */
class CallResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'conversation_id' => $this->conversation_id,
            'type' => $this->type->value,
            'status' => $this->status->value,
            'caller' => new MatchedUserResource($this->caller),
            'callee' => new MatchedUserResource($this->callee),
            'started_at' => $this->started_at,
            'ended_at' => $this->ended_at,
            'duration_seconds' => $this->duration_seconds,
            'created_at' => $this->created_at,
        ];
    }
}
