<?php

namespace Tests\Feature\Notifications;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_use_any_notification_endpoint(): void
    {
        $notification = Notification::factory()->create();

        $this->getJson('/api/v1/notifications')->assertUnauthorized();
        $this->putJson("/api/v1/notifications/{$notification->id}/read")->assertUnauthorized();
        $this->putJson('/api/v1/notifications/read-all')->assertUnauthorized();
    }

    public function test_a_user_sees_only_their_own_notifications(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        Notification::factory()->create(['user_id' => $user->id]);
        Notification::factory()->create(); // someone else's

        $response = $this->getJson('/api/v1/notifications')->assertOk();
        $response->assertJsonCount(1, 'notifications');
    }

    public function test_unread_notifications_sort_before_read_ones_then_newest_first(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $oldUnread = Notification::factory()->create(['user_id' => $user->id]);
        $newUnread = Notification::factory()->create(['user_id' => $user->id]);
        $read = Notification::factory()->read()->create(['user_id' => $user->id]);
        // created_at has useCurrent() and no factory override hook, same
        // bypass ChatTest uses for controlled ordering.
        DB::table('notifications')->where('id', $oldUnread->id)->update(['created_at' => now()->subMinutes(2)]);
        DB::table('notifications')->where('id', $newUnread->id)->update(['created_at' => now()->subMinute()]);
        DB::table('notifications')->where('id', $read->id)->update(['created_at' => now()]);

        $response = $this->getJson('/api/v1/notifications')->assertOk();

        $response->assertJsonPath('notifications.0.id', $newUnread->id);
        $response->assertJsonPath('notifications.1.id', $oldUnread->id);
        $response->assertJsonPath('notifications.2.id', $read->id);
    }

    public function test_a_user_can_mark_one_notification_read(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $notification = Notification::factory()->create(['user_id' => $user->id]);

        $response = $this->putJson("/api/v1/notifications/{$notification->id}/read")->assertOk();

        $response->assertJsonPath('notification.id', $notification->id);
        $this->assertNotNull($notification->fresh()->read_at);
    }

    public function test_a_user_cannot_mark_someone_elses_notification_read(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $notification = Notification::factory()->create();

        $this->putJson("/api/v1/notifications/{$notification->id}/read")->assertForbidden();
        $this->assertNull($notification->fresh()->read_at);
    }

    public function test_mark_all_read_only_affects_the_callers_own_unread_notifications(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $mine = Notification::factory()->create(['user_id' => $user->id]);
        $someoneElses = Notification::factory()->create();

        $this->putJson('/api/v1/notifications/read-all')->assertOk();

        $this->assertNotNull($mine->fresh()->read_at);
        $this->assertNull($someoneElses->fresh()->read_at);
    }
}
