<?php

namespace App\Events;

use App\Http\Resources\Calls\CallResource;
use App\Models\Call;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast for every terminal state (ended/missed/declined) — one event,
 * `call.status` in the payload tells the other side's client which
 * end-of-call UI to show. Both participants tear down their local
 * RTCPeerConnection on receipt of this, not just on their own hang-up
 * action.
 */
class CallEndedBroadcast implements ShouldBroadcastNow
{
    use InteractsWithSockets, SerializesModels;

    public function __construct(public readonly Call $call) {}

    public function broadcastOn(): array
    {
        return [new PresenceChannel('conversation.'.$this->call->conversation_id)];
    }

    public function broadcastAs(): string
    {
        return 'call.ended';
    }

    public function broadcastWith(): array
    {
        return ['call' => (new CallResource($this->call))->resolve()];
    }
}
