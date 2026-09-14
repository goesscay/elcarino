<?php

namespace App\Http\Controllers\Api\Chat;

use App\Enums\MessageType;
use App\Events\MessagesReadBroadcast;
use App\Events\NewMessageBroadcast;
use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Chat\SendMessageRequest;
use App\Http\Resources\Chat\ConversationResource;
use App\Http\Resources\Chat\MessageResource;
use App\Models\Block;
use App\Models\Conversation;
use App\Services\Gifs\GifProvider;
use App\Services\Media\AudioMimeTypeResolver;
use App\Services\Notifications\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ChatController extends Controller
{
    use RespondsWithErrorEnvelope;

    public function __construct(
        private readonly NotificationService $notifications,
        private readonly AudioMimeTypeResolver $audioMimeTypes,
        private readonly GifProvider $gifs,
    ) {}

    /**
     * GET /api/v1/chat/conversations — inbox, most-recently-active first.
     * A brand new match with no messages yet (last_message_at null) sorts to
     * the end, not lost — docs/07 §3.3 shows those in the inbox too.
     *
     * Excludes any conversation whose other participant is blocked in
     * either direction (Phase 1 item 10) — `ConversationPolicy::view`
     * already rejects opening one of these with a 403, but before this the
     * inbox listing itself didn't know about blocks at all, so a blocked
     * conversation stayed visible right up until the moment tapping it
     * failed. Caught while building the mobile Block header action, not by
     * a report — blocks were always schema-only until this same feature, so
     * the gap was dormant until real block rows could exist.
     */
    public function index(Request $request): JsonResponse
    {
        $viewer = $request->user();

        $blockedUserIds = Block::query()
            ->where(fn ($q) => $q->where('blocker_id', $viewer->id)->orWhere('blocked_id', $viewer->id))
            ->get(['blocker_id', 'blocked_id'])
            ->flatMap(fn (Block $b) => [$b->blocker_id, $b->blocked_id])
            ->reject(fn (int $id) => $id === $viewer->id)
            ->unique();

        $conversations = Conversation::query()
            ->where(fn ($q) => $q->where('user_one_id', $viewer->id)->orWhere('user_two_id', $viewer->id))
            ->whereNotIn('user_one_id', $blockedUserIds)
            ->whereNotIn('user_two_id', $blockedUserIds)
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
            ->with('attachment')
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

        $voiceNote = $request->file('voice_note');
        $gifId = $request->string('gif_id')->toString();

        $gif = null;
        if ($gifId !== '') {
            $gif = $this->gifs->find($gifId);
            if (! $gif) {
                return $this->errorResponse('gif_not_found', 'That gif is no longer available.', 422);
            }
        }

        $message = $conversation->messages()->create([
            'sender_id' => $request->user()->id,
            // null body for a voice-note message — docs/02's schema note
            // ("null if attachment-only"), matching the migration comment.
            // A gif message stores the *resolved* (server-side, re-fetched —
            // see SendMessageRequest's gif_id doc comment) url in body, the
            // same field a text message uses — no message_attachments row:
            // unlike a voice note or photo, a gif is already public,
            // third-party-hosted content, nothing here to store privately or
            // mint a signed URL for.
            'body' => match (true) {
                $voiceNote !== null => null,
                $gif !== null => $gif->url,
                default => $request->string('body')->toString(),
            },
            'type' => match (true) {
                $voiceNote !== null => MessageType::VoiceNote,
                $gif !== null => MessageType::Gif,
                default => MessageType::Text,
            },
        ]);

        if ($voiceNote) {
            $path = Storage::disk(config('filesystems.default'))->putFileAs(
                'voice-notes/'.$conversation->id,
                $voiceNote,
                Str::uuid().'.'.$voiceNote->extension(),
            );

            $mimeType = $this->audioMimeTypes->resolve($voiceNote->extension(), $voiceNote->getMimeType());

            $message->setRelation('attachment', $message->attachment()->create([
                'storage_path' => $path,
                'mime_type' => $mimeType,
                'duration_seconds' => $request->integer('duration_seconds'),
            ]));
        } else {
            // Populate the relation so MessageResource::whenLoaded('attachment')
            // resolves to null rather than being omitted entirely.
            $message->setRelation('attachment', null);
        }

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
