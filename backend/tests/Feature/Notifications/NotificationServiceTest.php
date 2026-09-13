<?php

namespace Tests\Feature\Notifications;

use App\Models\User;
use App\Models\UserDevice;
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

    private function fakeSender(): PushSender
    {
        return new class implements PushSender
        {
            public function send(string $fcmToken, string $title, string $body, array $data = []): void {}
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
