<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Queue\SerializesModels;

/**
 * Lets the sender's open conversation screen flip a message to "read" live,
 * without polling — the read receipt itself (docs/07 §3.3: "read receipt on
 * last own message") is set by ChatController::markRead; this just notifies
 * the other participant's client that it happened.
 */
class MessagesReadBroadcast implements ShouldBroadcastNow
{
    use InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly int $conversationId,
        public readonly int $readByUserId,
        public readonly string $readAt,
    ) {}

    public function broadcastOn(): array
    {
        return [new PresenceChannel('conversation.'.$this->conversationId)];
    }

    public function broadcastAs(): string
    {
        return 'messages.read';
    }

    public function broadcastWith(): array
    {
        return ['read_by_user_id' => $this->readByUserId, 'read_at' => $this->readAt];
    }
}
