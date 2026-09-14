<?php

namespace App\Http\Controllers\Api\Calls;

use App\Enums\CallStatus;
use App\Enums\CallType;
use App\Events\CallAnsweredBroadcast;
use App\Events\CallEndedBroadcast;
use App\Events\CallIncomingBroadcast;
use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Calls\StartCallRequest;
use App\Http\Resources\Calls\CallResource;
use App\Models\Call;
use App\Models\Conversation;
use App\Services\Calls\IceServerResolver;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

/**
 * Phase 3 items 4/5 (voice + video calling, open decisions #19/#20,
 * confirmed WebRTC). The actual WebRTC signaling (SDP offer/answer, ICE
 * candidates) never touches this controller or any REST endpoint — it's a
 * peer-to-peer client whisper over the same `presence-conversation.{id}`
 * channel chat's typing indicator already uses (see docs/03 "Calls"). This
 * controller only manages the call's lifecycle/authorization and broadcasts
 * the three state-change events the other participant's client reacts to.
 *
 * Scope disclosed up front, not silently assumed away: a call only reaches
 * the callee if their app is already subscribed to this conversation's
 * presence channel — in practice, `ConversationScreen` open. There's no
 * VoIP/CallKit-style wake-from-background path (that needs native
 * PushKit/ConnectionService integration well beyond a Flutter plugin, out
 * of scope for this pass) and no push notification for a missed call
 * either. A real production launch needs that; this doesn't have it yet.
 */
class CallController extends Controller
{
    use RespondsWithErrorEnvelope;

    public function __construct(private readonly IceServerResolver $ice) {}

    /**
     * POST /api/v1/calls/token — the caller starts a call. docs/03's
     * original `[PROPOSED]` name for this endpoint ("issues a session
     * token") predates the provider decision; kept as-is since a WebRTC
     * "token" is just this response's `ice_servers` + the created call's id
     * rather than an opaque provider credential, same intent either way.
     */
    public function token(StartCallRequest $request): JsonResponse
    {
        $conversation = Conversation::findOrFail($request->integer('conversation_id'));
        Gate::authorize('call', $conversation);

        // spec §13: "Match → subscriber? → yes: voice/video, no: upgrade
        // prompt" — unlike unmatched-messaging (docs/06 §3.4), calling has
        // no "unless you're a subscriber" carve-out for a missing/inactive
        // match; both conditions are mandatory.
        if ($conversation->match === null || ! $conversation->match->isActive()) {
            return $this->errorResponse(
                'active_match_required',
                'You can only call someone you\'re currently matched with.',
                403,
            );
        }

        if (! $request->user()->isSubscriber()) {
            return $this->errorResponse(
                'subscription_required',
                'Subscribe to make voice and video calls.',
                403,
            );
        }

        $call = Call::query()->create([
            'conversation_id' => $conversation->id,
            'caller_id' => $request->user()->id,
            'callee_id' => $conversation->otherUser($request->user())->id,
            'type' => CallType::from($request->string('type')->toString()),
            'status' => CallStatus::Ringing,
        ]);
        $call->setRelation('conversation', $conversation);

        broadcast(new CallIncomingBroadcast($call));

        return response()->json([
            'call' => new CallResource($call),
            'ice_servers' => $this->ice->resolve(),
        ], 201);
    }

    /**
     * POST /api/v1/calls/{call}/answer — the callee answers. Also the
     * callee's own route to the same `ice_servers` config the caller got
     * from `token` (the callee never calls `token` themselves — that would
     * create a *second* call row).
     */
    public function answer(Request $request, Call $call): JsonResponse
    {
        Gate::authorize('answer', $call);

        if ($call->status !== CallStatus::Ringing) {
            return $this->errorResponse('call_not_ringing', 'This call is no longer ringing.', 422);
        }

        $call->forceFill(['status' => CallStatus::Active, 'started_at' => now()])->save();

        broadcast(new CallAnsweredBroadcast($call));

        return response()->json([
            'call' => new CallResource($call),
            'ice_servers' => $this->ice->resolve(),
        ]);
    }

    /**
     * POST /api/v1/calls/{call}/decline — the callee explicitly rejects it
     * (distinct from `end` while ringing, which means the *caller* gave up
     * or it simply timed out client-side — see that method's doc comment).
     */
    public function decline(Request $request, Call $call): JsonResponse
    {
        Gate::authorize('decline', $call);

        if ($call->status !== CallStatus::Ringing) {
            return $this->errorResponse('call_not_ringing', 'This call is no longer ringing.', 422);
        }

        $call->forceFill([
            'status' => CallStatus::Declined,
            'ended_at' => now(),
            'ended_by' => $request->user()->id,
        ])->save();

        broadcast(new CallEndedBroadcast($call));

        return response()->json(['call' => new CallResource($call)]);
    }

    /**
     * POST /api/v1/calls/{call}/end — either participant hangs up.
     * Idempotent by design (returns the call's current state rather than
     * erroring) rather than racing both participants' near-simultaneous
     * hang-ups against each other — whichever request reaches the database
     * first wins, the second just sees it's already ended.
     */
    public function end(Request $request, Call $call): JsonResponse
    {
        Gate::authorize('end', $call);

        if (in_array($call->status, [CallStatus::Ringing, CallStatus::Active], true)) {
            // Still ringing and nobody answered → missed, not "ended" —
            // regardless of *which* participant ends it (the caller giving
            // up, or the callee's `end` instead of an explicit `decline`),
            // the meaningful fact for analytics/support is that the call
            // never connected.
            $wasActive = $call->status === CallStatus::Active;

            $call->forceFill([
                'status' => $wasActive ? CallStatus::Ended : CallStatus::Missed,
                'ended_at' => now(),
                'ended_by' => $request->user()->id,
                // `(int)` — Carbon's `diffInSeconds` returns a float, which
                // `json_encode` then prints as a whole-number float (e.g.
                // `60.0` rather than `60`) that the mobile client's `as
                // int?` cast rejected outright (see Call.fromJson's own
                // comment) — caught live: it silently crashed both the
                // caller's own end-call handling and the callee's
                // `call.ended` broadcast listener for any call that reached
                // `active`. Mobile now parses defensively via `num?`
                // regardless, but this is the actual source of the bad
                // shape, so fix it here too rather than relying solely on
                // the client tolerating it.
                'duration_seconds' => $wasActive && $call->started_at
                    ? (int) $call->started_at->diffInSeconds(now())
                    : null,
            ])->save();

            broadcast(new CallEndedBroadcast($call));
        }

        return response()->json(['call' => new CallResource($call)]);
    }
}
