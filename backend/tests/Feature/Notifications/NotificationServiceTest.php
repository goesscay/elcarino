<?php

namespace Tests\Feature\Notifications;

use App\Models\Conversation;
use App\Models\User;
use App\Models\UserDevice;
use App\Models\UserMatch;
use App\Services\Notifications\NotificationService;
use App\Services\Push\PushSender;
use App\Services\Push\PushSendException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class NotificationServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_recipient_with_no_devices_still_gets_the_notification_row(): void
    {
        $user = User::factory()->create();
        $service = new NotificationService($this->fakeSender());

        $service->notifyLike($user);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $user->id,
            'type' => 'like',
            'sent_via_push' => false,
        ]);
    }

    public function test_sent_via_push_is_true_once_at_least_one_device_receives_it(): void
    {
        $user = User::factory()->create();
        UserDevice::factory()->create(['user_id' => $user->id]);
        $service = new NotificationService($this->fakeSender());

        $service->notifyLike($user);

        $this->assertDatabaseHas('notifications', ['user_id' => $user->id, 'sent_via_push' => true]);
    }

    public function test_a_push_failure_on_one_device_does_not_stop_the_notification_being_recorded(): void
    {
        $user = User::factory()->create();
        UserDevice::factory()->create(['user_id' => $user->id, 'fcm_token' => 'stale-token']);
        $service = new NotificationService($this->alwaysFailingSender());

        // Must not throw — a dead FCM token is not the caller's problem
        // (the swipe/message that triggered this already succeeded).
        $service->notifyLike($user);

        $this->assertDatabaseHas('notifications', ['user_id' => $user->id, 'sent_via_push' => false]);
    }

    public function test_the_stored_payload_is_merged_into_the_fcm_data_for_deep_linking(): void
    {
        $recipient = User::factory()->create();
        $other = User::factory()->create();
        UserDevice::factory()->create(['user_id' => $recipient->id]);
        $sender = $this->capturingSender();
        $service = new NotificationService($sender);
        $match = UserMatch::factory()->between($recipient, $other)->create();
        $conversation = Conversation::query()->create([
            'match_id' => $match->id,
            'user_one_id' => min($recipient->id, $other->id),
            'user_two_id' => max($recipient->id, $other->id),
        ]);

        $service->notifyNewMatch($match, $conversation, $recipient, $other);

        // FCM's data payload requires string values — every value merged in
        // must have been cast, not passed through as the original int.
        $this->assertSame((string) $conversation->id, $sender->lastData['conversation_id']);
        $this->assertSame((string) $match->id, $sender->lastData['match_id']);
        $this->assertSame('new_match', $sender->lastData['type']);
    }

    private function fakeSender(): PushSender
    {
        return new class implements PushSender
        {
            public function send(string $fcmToken, string $title, string $body, array $data = []): void {}
        };
    }

    private function capturingSender(): PushSender
    {
        return new class implements PushSender
        {
            public array $lastData = [];

            public function send(string $fcmToken, string $title, string $body, array $data = []): void
            {
                $this->lastData = $data;
            }
        };
    }

    private function alwaysFailingSender(): PushSender
    {
        return new class implements PushSender
        {
            public function send(string $fcmToken, string $title, string $body, array $data = []): void
            {
                throw new PushSendException('device token no longer registered');
            }
        };
    }
}
