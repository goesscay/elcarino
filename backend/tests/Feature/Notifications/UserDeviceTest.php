<?php

namespace Tests\Feature\Notifications;

use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserDeviceTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_use_any_device_endpoint(): void
    {
        $device = UserDevice::factory()->create();

        $this->getJson('/api/v1/users/me/devices')->assertUnauthorized();
        $this->postJson('/api/v1/users/me/devices', ['fcm_token' => 'x', 'platform' => 'ios'])
            ->assertUnauthorized();
        $this->deleteJson("/api/v1/users/me/devices/{$device->id}")->assertUnauthorized();
    }

    public function test_a_user_can_register_a_device(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $response = $this->postJson('/api/v1/users/me/devices', [
            'fcm_token' => 'token-123',
            'platform' => 'android',
            'app_version' => '2.1.0',
        ]);

        $response->assertCreated();
        $response->assertJsonPath('device.platform', 'android');
        $response->assertJsonMissingPath('device.fcm_token');
        $this->assertDatabaseHas('user_devices', [
            'user_id' => $user->id,
            'fcm_token' => 'token-123',
            'platform' => 'android',
        ]);
    }

    public function test_registering_the_same_token_twice_updates_rather_than_duplicates(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        UserDevice::factory()->create(['user_id' => $user->id, 'fcm_token' => 'token-123', 'app_version' => '1.0.0']);

        $this->postJson('/api/v1/users/me/devices', [
            'fcm_token' => 'token-123',
            'platform' => 'ios',
            'app_version' => '2.0.0',
        ])->assertCreated();

        $this->assertDatabaseCount('user_devices', 1);
        $this->assertDatabaseHas('user_devices', ['fcm_token' => 'token-123', 'app_version' => '2.0.0']);
    }

    public function test_registering_a_token_already_owned_by_another_account_reassigns_it(): void
    {
        // Same installation: user A logs out, user B logs in on the same
        // device, the OS hands the app the same FCM token back.
        $userA = User::factory()->create();
        UserDevice::factory()->create(['user_id' => $userA->id, 'fcm_token' => 'shared-token']);
        Sanctum::actingAs($userB = User::factory()->create());

        $this->postJson('/api/v1/users/me/devices', [
            'fcm_token' => 'shared-token',
            'platform' => 'ios',
        ])->assertCreated();

        $this->assertDatabaseCount('user_devices', 1);
        $this->assertDatabaseHas('user_devices', ['fcm_token' => 'shared-token', 'user_id' => $userB->id]);
    }

    public function test_registering_requires_a_valid_platform(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/users/me/devices', ['fcm_token' => 'x', 'platform' => 'windows'])
            ->assertStatus(422)->assertJsonValidationErrors('platform');
    }

    public function test_a_user_sees_only_their_own_devices(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        UserDevice::factory()->create(['user_id' => $user->id]);
        UserDevice::factory()->create(); // someone else's

        $response = $this->getJson('/api/v1/users/me/devices')->assertOk();
        $response->assertJsonCount(1, 'devices');
    }

    public function test_a_user_can_remove_their_own_device(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $device = UserDevice::factory()->create(['user_id' => $user->id]);

        $this->deleteJson("/api/v1/users/me/devices/{$device->id}")->assertOk();
        $this->assertDatabaseMissing('user_devices', ['id' => $device->id]);
    }

    public function test_a_user_cannot_remove_someone_elses_device(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $device = UserDevice::factory()->create();

        $this->deleteJson("/api/v1/users/me/devices/{$device->id}")->assertForbidden();
        $this->assertDatabaseHas('user_devices', ['id' => $device->id]);
    }
}
