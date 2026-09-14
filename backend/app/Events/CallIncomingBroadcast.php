<?php

namespace App\Events;

use App\Http\Resources\Calls\CallResource;
use App\Models\Call;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Queue\SerializesModels;

/**
 * Phase 3 items 4/5 (calling, open decisions #19/#20, confirmed WebRTC).
 * Broadcast the moment CallController::token creates the call — the
 * callee's client, if it's subscribed to this conversation's presence
 * channel (see that controller's doc comment for the "app must be on this
 * screen" scope this pass is built to), shows the incoming-call UI from
 * this alone. The actual WebRTC offer/answer/ICE-candidate exchange is a
 * *separate*, peer-to-peer whisper on the same channel — never a
 * broadcast — see docs/03 "Calls".
 */
class CallIncomingBroadcast implements ShouldBroadcastNow
{
    use InteractsWithSockets, SerializesModels;

    public function __construct(public readonly Call $call) {}

    public function broadcastOn(): array
    {
        return [new PresenceChannel('conversation.'.$this->call->conversation_id)];
    }

    public function broadcastAs(): string
    {
        return 'call.incoming';
    }

    public function broadcastWith(): array
    {
        return ['call' => (new CallResource($this->call))->resolve()];
    }
}
