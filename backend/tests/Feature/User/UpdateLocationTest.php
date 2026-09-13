<?php

namespace Tests\Feature\User;

use App\Models\User;
use App\Models\UserLocation;
use App\Services\Geo\Geohash;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UpdateLocationTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_update_their_location(): void
    {
        $this->putJson('/api/v1/users/me/location', ['latitude' => 3.139, 'longitude' => 101.687])
            ->assertUnauthorized();
    }

    public function test_a_user_can_set_their_location(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $response = $this->putJson('/api/v1/users/me/location', [
            'latitude' => 3.1390123,
            'longitude' => 101.6870456,
        ]);

        $response->assertOk();
        // Never echoes coordinates back (docs/06 §4/§5).
        $response->assertJsonMissingPath('latitude')->assertJsonMissingPath('longitude');

        $this->assertDatabaseHas('user_locations', [
            'user_id' => $user->id,
            // Rounded to 3 decimal places server-side, defense-in-depth.
            'latitude' => 3.139,
            'longitude' => 101.687,
            'geohash' => Geohash::encode(3.139, 101.687),
        ]);
    }

    public function test_updating_again_overwrites_rather_than_duplicating(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $this->putJson('/api/v1/users/me/location', ['latitude' => 3.139, 'longitude' => 101.687])->assertOk();
        $this->travel(6)->minutes();
        $this->putJson('/api/v1/users/me/location', ['latitude' => 4.0, 'longitude' => 102.0])->assertOk();

        $this->assertSame(1, UserLocation::query()->where('user_id', $user->id)->count());
        $this->assertDatabaseHas('user_locations', ['user_id' => $user->id, 'latitude' => 4.0]);
    }

    public function test_it_rejects_out_of_range_coordinates(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/v1/users/me/location', ['latitude' => 91, 'longitude' => 200])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['latitude', 'longitude']);
    }

    public function test_it_enforces_the_documented_one_update_per_5_minutes_limit(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/v1/users/me/location', ['latitude' => 3.139, 'longitude' => 101.687])->assertOk();
        $this->putJson('/api/v1/users/me/location', ['latitude' => 3.14, 'longitude' => 101.69])
            ->assertStatus(429);
    }
}
