<?php

namespace App\Services\Notifications;

use App\Enums\NotificationType;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\Notification;
use App\Models\User;
use App\Models\UserMatch;
use App\Services\Push\PushSender;
use App\Services\Push\PushSendException;
use Illuminate\Support\Facades\Log;

/**
 * Phase 1 item 9. Always creates the persisted `Notification` row
 * (docs/02-database-schema.md) so the in-app notification feed is
 * complete even for a user with no registered devices, then best-effort
 * pushes it to every device the recipient has. A push failure never blocks
 * or rolls back the action that triggered it (a swipe/match/message already
 * succeeded by the time this runs) — it just leaves `sent_via_push` false.
 */
class NotificationService
{
    public function __construct(private readonly PushSender $push) {}

    /**
     * Fires for both participants — SwipeService calls this right after
     * creating the match (and its Conversation, item 8).
     */
    public function notifyNewMatch(UserMatch $match, Conversation $conversation, User $userOne, User $userTwo): void
    {
        $this->notifyOneMatch($match, $conversation, notify: $userOne, about: $userTwo);
        $this->notifyOneMatch($match, $conversation, notify: $userTwo, about: $userOne);
    }

    private function notifyOneMatch(UserMatch $match, Conversation $conversation, User $notify, User $about): void
    {
        $name = $about->profile?->display_name ?? 'Someone';

        $this->notify($notify, NotificationType::NewMatch, "It's a match!", "You and {$name} liked each other.", [
            'match_id' => $match->id,
            'conversation_id' => $conversation->id,
            'other_user_id' => $about->id,
        ]);
    }

    /**
     * Fires for the *other* participant — ChatController::sendMessage calls
     * this right after the message is created and broadcast.
     */
    public function notifyNewMessage(Message $message): void
    {
        $conversation = $message->conversation;
        $recipient = $conversation->otherUser($message->sender);
        $senderName = $message->sender->profile?->display_name ?? 'Someone';

        $this->notify($recipient, NotificationType::NewMessage, $senderName, (string) $message->body, [
            'conversation_id' => $conversation->id,
            'message_id' => $message->id,
        ]);
    }

    /**
     * Fires for the swiped-on user when a right/super swipe doesn't
     * (yet) reciprocate into a match — SwipeService calls this from the
     * same branch that writes to `likes`.
     *
     * Deliberately carries no identity of the liker, in the push body or
     * the stored payload — "who liked me" is a separate, premium-gated
     * browsing feature (Phase 2, reads the `likes` table directly per
     * docs/03's `GET /matches/who-liked-me`); leaking the id here would let
     * a free user bypass that gate for free, the same "no derivative
     * signal leaks precision" principle docs/06 §4 applies to location.
     */
    public function notifyLike(User $target): void
    {
        $this->notify($target, NotificationType::Like, 'New like!', 'Someone likes you.', []);
    }

    private function notify(User $recipient, NotificationType $type, string $title, string $body, array $payload): void
    {
        $notification = Notification::query()->create([
            'user_id' => $recipient->id,
            'type' => $type,
            'payload' => $payload,
            'sent_via_push' => false,
        ]);

        $sentToAny = false;
        foreach ($recipient->devices as $device) {
            try {
                $this->push->send($device->fcm_token, $title, $body, [
                    'type' => $type->value,
                    'notification_id' => (string) $notification->id,
                ]);
                $sentToAny = true;
            } catch (PushSendException $e) {
                Log::warning('Push notification send failed.', [
                    'device_id' => $device->id,
                    'notification_id' => $notification->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        if ($sentToAny) {
            $notification->update(['sent_via_push' => true]);
        }
    }
}
