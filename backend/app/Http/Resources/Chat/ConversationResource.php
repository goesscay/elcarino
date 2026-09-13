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

        return [
            'id' => $this->id,
            // So the mobile inbox (one GET /chat/conversations call) can
            // also call DELETE /matches/{match_id} to unmatch, without a
            // second round-trip to GET /matches just to find this id.
            'match_id' => $this->match_id,
            'other_user' => new MatchedUserResource($other),
            'last_message_at' => $this->last_message_at,
            'unread_count' => $unreadCount,
            // Whether sending a message here needs an active subscription
            // (docs/06 §3.4) — lets the client show the "subscribe to
            // message" banner without a wasted 403 round-trip.
            'requires_subscription_to_message' => $this->requiresSubscriptionToMessage(),
        ];
    }
}
