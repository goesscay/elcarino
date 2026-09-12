<?php

namespace App\Http\Resources\Profile;

use App\Models\ProfilePrompt;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A library prompt (docs/03 `GET /prompts`) — not the current user's answer.
 *
 * @mixin ProfilePrompt
 */
class ProfilePromptResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'prompt' => $this->prompt,
            'category' => $this->category,
        ];
    }
}
