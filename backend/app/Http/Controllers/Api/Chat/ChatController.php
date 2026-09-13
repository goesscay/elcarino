<?php

namespace App\Http\Controllers\Api\Chat;

use App\Events\MessagesReadBroadcast;
use App\Events\NewMessageBroadcast;
use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Chat\SendMessageRequest;
use App\Http\Resources\Chat\ConversationResource;
use App\Http\Resources\Chat\MessageResource;
use App\Models\Conversation;
use App\Services\Notifications\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class ChatController extends Controller
{
    use RespondsWithErrorEnvelope;

    public function __construct(private readonly NotificationService $notifications) {}

    /**
     * GET /api/v1/chat/conversations — inbox, most-recently-active first.
     * A brand new match with no messages yet (last_message_at null) sorts to
     * the end, not lost — docs/07 §3.3 shows those in the inbox too.
     */
    public function index(Request $request): JsonResponse
    {
        $viewer = $request->user();

        $conversations = Conversation::query()
            ->where(fn ($q) => $q->where('user_one_id', $viewer->id)->orWhere('user_two_id', $viewer->id))
            ->with(['userOne.profile.photos', 'userTwo.profile.photos', 'match'])
            ->orderByRaw('last_message_at IS NULL, last_message_at DESC')
            ->get();

        return response()->json([
            'conversations' => $conversations->map(
                fn (Conversation $c) => new ConversationResource($c, $viewer->id),
            ),
        ]);
    }

    /**
     * GET /api/v1/chat/conversations/{conversation}/messages — newest first.
     */
    public function messages(Request $request, Conversation $conversation): JsonResponse
    {
        Gate::authorize('view', $conversation);

        $perPage = min(
            (int) $request->integer('per_page', config('chat.default_per_page')),
            config('chat.max_per_page'),
        );

        // The messages() relation itself orders ascending (natural read
        // order for a fully-loaded conversation) — reorder() clears that so
        // this listing's own newest-first pagination isn't fighting it.
        $messages = $conversation->messages()
            ->reorder('created_at', 'desc')
            ->paginate($perPage);

        return response()->json([
            'messages' => MessageResource::collection($messages->items()),
            'meta' => [
                'page' => $messages->currentPage(),
                'per_page' => $messages->perPage(),
                'has_more' => $messages->hasMorePages(),
            ],
        ]);
    }

    /**
     * POST /api/v1/chat/conversations/{conversation}/messages
     */
    public function sendMessage(SendMessageRequest $request, Conversation $conversation): JsonResponse
    {
        Gate::authorize('sendMessage', $conversation);

        // The mandatory unmatched-messaging gate — docs/01 §12 / docs/06
        // §3.4: enforced here at the API layer, not left to the mobile UI.
        if ($conversation->requiresSubscriptionToMessage() && ! $request->user()->isSubscriber()) {
            return $this->errorResponse(
                'subscription_required',
                "Subscribe to message people you haven't matched with.",
                403,
            );
        }

        $message = $conversation->messages()->create([
            'sender_id' => $request->user()->id,
            'body' => $request->string('body')->toString(),
        ]);

        $conversation->forceFill(['last_message_at' => $message->created_at])->save();

        broadcast(new NewMessageBroadcast($message));
        $this->notifications->notifyNewMessage($message);

        return response()->json(['message' => new MessageResource($message)], 201);
    }

    /**
     * PUT /api/v1/chat/conversations/{conversation}/read
     */
    public function markRead(Request $request, Conversation $conversation): JsonResponse
    {
        Gate::authorize('view', $conversation);

        $viewer = $request->user();
        $now = now();

        $updated = $conversation->messages()
            ->where('sender_id', '!=', $viewer->id)
            ->whereNull('read_at')
            ->update(['read_at' => $now]);

        if ($updated > 0) {
            broadcast(new MessagesReadBroadcast($conversation->id, $viewer->id, $now->toIso8601String()));
        }

        return response()->json(['message' => 'Marked read.']);
    }
}
