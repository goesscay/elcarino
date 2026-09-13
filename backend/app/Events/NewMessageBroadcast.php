<?php

namespace App\Events;

use App\Http\Resources\Chat\MessageResource;
use App\Models\Message;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Queue\SerializesModels;

/**
 * docs/03-api-specification.md: `presence:conversation.{id}` — real-time
 * message delivery. ShouldBroadcastNow (not the queued ShouldBroadcast):
 * QUEUE_CONNECTION is `database` locally with no queue worker guaranteed to
 * be running, and a chat message that silently never arrives because nobody
 * ran `queue:work` would be a bad and confusing failure mode. Broadcasting
 * synchronously costs one extra HTTP round-trip to Reverb per message, which
 * is the right trade for correctness here.
 */
class NewMessageBroadcast implements ShouldBroadcastNow
{
    use InteractsWithSockets, SerializesModels;

    public function __construct(public readonly Message $message) {}

    public function broadcastOn(): array
    {
        return [new PresenceChannel('conversation.'.$this->message->conversation_id)];
    }

    public function broadcastAs(): string
    {
        return 'message.new';
    }

    public function broadcastWith(): array
    {
        return ['message' => (new MessageResource($this->message))->resolve()];
    }
}
