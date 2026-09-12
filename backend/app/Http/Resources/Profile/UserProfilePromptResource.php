<?php

namespace App\Http\Resources\Profile;

use App\Models\UserProfilePrompt;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The current user's own answered prompt (docs/03 `GET/PUT /prompts/me`).
 *
 * @mixin UserProfilePrompt
 */
class UserProfilePromptResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'prompt_id' => $this->prompt_id,
            'prompt' => $this->whenLoaded('prompt', fn () => $this->prompt->prompt),
            'answer' => $this->answer,
            'sort_order' => $this->sort_order,
        ];
    }
}
