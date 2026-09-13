<?php

namespace Database\Factories;

use App\Models\User;
use App\Models\UserLocation;
use App\Services\Geo\Geohash;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<UserLocation>
 */
class UserLocationFactory extends Factory
{
    public function definition(): array
    {
        // Default: central Kuala Lumpur (launch market #1 — docs/00 quick facts).
        $latitude = 3.139;
        $longitude = 101.687;

        return [
            'user_id' => User::factory(),
            'latitude' => $latitude,
            'longitude' => $longitude,
            'geohash' => Geohash::encode($latitude, $longitude),
        ];
    }

    public function at(float $latitude, float $longitude): static
    {
        return $this->state(fn (array $attributes) => [
            'latitude' => $latitude,
            'longitude' => $longitude,
            'geohash' => Geohash::encode($latitude, $longitude),
        ]);
    }
}
