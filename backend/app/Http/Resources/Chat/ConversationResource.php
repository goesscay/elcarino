<?php

namespace App\Http\Resources\Chat;

use App\Http\Resources\Matches\MatchedUserResource;
use App\Models\Conversation;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Conversation
 */
class ConversationResource extends JsonResource
{
    public function __construct(Conversation $resource, private readonly int $viewerId)
    {
        parent::__construct($resource);
    }

    public function toArray(Request $request): array
    {
        $viewer = $this->user_one_id === $this->viewerId ? $this->userOne : $this->userTwo;
        $other = $this->user_one_id === $this->viewerId ? $this->userTwo : $this->userOne;

        $unreadCount = $this->messages()
            ->where('sender_id', '!=', $viewer->id)
            ->whereNull('read_at')
            ->count();

        // docs/07 §3.3's inbox row needs a preview snippet next to the
        // timestamp. reorder() is required here for the same reason as
        // ChatController::messages() — the messages() relation's own
        // ascending orderBy('created_at') would otherwise silently combine
        // with a second orderByDesc instead of being replaced by it.
        $lastMessage = $this->messages()->reorder('created_at', 'desc')->first();

        return [
            'id' => $this->id,
            // So the mobile inbox (one GET /chat/conversations call) can
            // also call DELETE /matches/{match_id} to unmatch, without a
            // second round-trip to GET /matches just to find this id.
            'match_id' => $this->match_id,
            'other_user' => new MatchedUserResource($other),
            'last_message_at' => $this->last_message_at,
            // Null for a fresh match with no messages yet — the mobile inbox
            // falls back to "You matched — say hi!" in that case.
            'last_message_preview' => $lastMessage?->body,
            'unread_count' => $unreadCount,
            // Whether sending a message here needs an active subscription
            // (docs/06 §3.4) — lets the client show the "subscribe to
            // message" banner without a wasted 403 round-trip.
            'requires_subscription_to_message' => $this->requiresSubscriptionToMessage(),
        ];
    }
}
