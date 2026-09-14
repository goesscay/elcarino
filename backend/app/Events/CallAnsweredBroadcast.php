<?php

namespace App\Events;

use App\Http\Resources\Calls\CallResource;
use App\Models\Call;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Queue\SerializesModels;

/**
 * Lets the *caller's* client flip its own UI from "ringing…" to
 * "connecting" the moment the callee answers, independent of and ahead of
 * whatever the WebRTC ICE connection state itself reports.
 */
class CallAnsweredBroadcast implements ShouldBroadcastNow
{
    use InteractsWithSockets, SerializesModels;

    public function __construct(public readonly Call $call) {}

    public function broadcastOn(): array
    {
        return [new PresenceChannel('conversation.'.$this->call->conversation_id)];
    }

    public function broadcastAs(): string
    {
        return 'call.answered';
    }

    public function broadcastWith(): array
    {
        return ['call' => (new CallResource($this->call))->resolve()];
    }
}
