<?php

namespace Tests\Feature\Profile;

use App\Models\Profile;
use App\Models\ProfilePhoto;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfilePhotoTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Storage::disk('local')->deleteDirectory('photos');
        parent::tearDown();
    }

    private function profileFor(User $user): Profile
    {
        return Profile::factory()->for($user)->create();
    }

    public function test_a_guest_cannot_upload_a_photo(): void
    {
        $this->postJson('/api/v1/profiles/me/photos', [
            'photo' => UploadedFile::fake()->image('photo.jpg'),
        ])->assertUnauthorized();
    }

    public function test_uploading_a_photo_requires_profile_basics_first(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/profiles/me/photos', [
            'photo' => UploadedFile::fake()->image('photo.jpg'),
        ])->assertStatus(422)->assertJsonPath('error.code', 'profile_not_found');
    }

    public function test_a_user_can_upload_a_photo(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $this->profileFor($user);

        $response = $this->postJson('/api/v1/profiles/me/photos', [
            'photo' => UploadedFile::fake()->image('photo.jpg', 800, 800),
        ]);

        $response->assertCreated()->assertJsonStructure([
            'photo' => ['id', 'url', 'sort_order', 'moderation_status'],
        ]);
        $response->assertJsonPath('photo.moderation_status', 'pending');

        $this->assertDatabaseCount('profile_photos', 1);

        // Re-encoded to JPEG and actually written to the (private) disk — not
        // just a DB row referencing a file that was never saved.
        $path = ProfilePhoto::query()->sole()->storage_path;
        Storage::disk('local')->assertExists($path);

        // completion_pct: basics (40, from the factory) + a photo (30) = 70.
        $this->assertSame(70, $user->profile()->first()->completion_pct);
    }

    public function test_rejects_a_non_image_upload(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $this->profileFor($user);

        $this->postJson('/api/v1/profiles/me/photos', [
            'photo' => UploadedFile::fake()->create('not-a-photo.txt', 10, 'text/plain'),
        ])->assertStatus(422)->assertJsonValidationErrors('photo');
    }

    public function test_photo_count_is_capped_at_the_configured_limit(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $this->profileFor($user);
        $max = config('media.max_photos_per_profile');

        for ($i = 0; $i < $max; $i++) {
            $this->postJson('/api/v1/profiles/me/photos', [
                'photo' => UploadedFile::fake()->image("photo{$i}.jpg"),
            ])->assertCreated();
        }

        $this->postJson('/api/v1/profiles/me/photos', [
            'photo' => UploadedFile::fake()->image('one-too-many.jpg'),
        ])->assertStatus(422)->assertJsonPath('error.code', 'photo_limit_reached');

        $this->assertDatabaseCount('profile_photos', $max);
    }

    public function test_a_user_can_delete_their_own_photo(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $profile = $this->profileFor($user);
        $photo = $profile->photos()->create(['storage_path' => 'photos/x/y.jpg', 'sort_order' => 0]);
        Storage::disk('local')->put($photo->storage_path, 'fake-bytes');

        $this->deleteJson("/api/v1/profiles/me/photos/{$photo->id}")->assertOk();

        $this->assertDatabaseMissing('profile_photos', ['id' => $photo->id]);
        Storage::disk('local')->assertMissing($photo->storage_path);
    }

    public function test_a_user_cannot_delete_another_users_photo(): void
    {
        $owner = User::factory()->create();
        $profile = $this->profileFor($owner);
        $photo = $profile->photos()->create(['storage_path' => 'photos/x/y.jpg', 'sort_order' => 0]);

        Sanctum::actingAs(User::factory()->create()); // a different user

        $this->deleteJson("/api/v1/profiles/me/photos/{$photo->id}")->assertForbidden();
        $this->assertDatabaseHas('profile_photos', ['id' => $photo->id]);
    }

    public function test_a_user_can_reorder_their_photos(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $profile = $this->profileFor($user);
        $first = $profile->photos()->create(['storage_path' => 'photos/a.jpg', 'sort_order' => 0]);
        $second = $profile->photos()->create(['storage_path' => 'photos/b.jpg', 'sort_order' => 1]);

        $this->putJson('/api/v1/profiles/me/photos/order', [
            'photo_ids' => [$second->id, $first->id],
        ])->assertOk();

        $this->assertSame(0, $second->fresh()->sort_order);
        $this->assertSame(1, $first->fresh()->sort_order);
    }

    public function test_reorder_rejects_ids_that_are_not_the_callers_own(): void
    {
        $other = User::factory()->create();
        $otherProfile = $this->profileFor($other);
        $otherPhoto = $otherProfile->photos()->create(['storage_path' => 'photos/a.jpg', 'sort_order' => 0]);

        Sanctum::actingAs($user = User::factory()->create());
        $profile = $this->profileFor($user);
        $mine = $profile->photos()->create(['storage_path' => 'photos/b.jpg', 'sort_order' => 0]);

        $this->putJson('/api/v1/profiles/me/photos/order', [
            'photo_ids' => [$mine->id, $otherPhoto->id],
        ])->assertStatus(422)->assertJsonPath('error.code', 'invalid_photo_ids');
    }
}
