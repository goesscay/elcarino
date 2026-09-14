<?php

namespace App\Http\Resources\Chat;

use App\Models\Message;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Message
 */
class MessageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'conversation_id' => $this->conversation_id,
            'sender_id' => $this->sender_id,
            'body' => $this->body,
            'type' => $this->type->value,
            // Only present for voice_note (and, later, gif/photo) messages —
            // relies on the caller eager-loading `attachment` so this isn't
            // an N+1 per message (see ChatController::messages/sendMessage).
            'attachment' => $this->whenLoaded(
                'attachment',
                fn () => $this->attachment ? new MessageAttachmentResource($this->attachment) : null,
            ),
            'read_at' => $this->read_at,
            'created_at' => $this->created_at,
        ];
    }
}
