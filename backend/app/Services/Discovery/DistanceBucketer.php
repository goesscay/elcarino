<?php

namespace App\Services\Discovery;

/**
 * docs/06-security-architecture.md §4: "Every distance shown to a client is
 * bucketed: `< 1 km` -> `"less than 1 km away"`; otherwise rounded to the
 * nearest km (or nearest 5 km beyond 30 km). The raw float is never
 * serialized." `0` is the sentinel for "less than 1 km" — the client renders
 * that copy, this API only ever returns the documented `distance_km` field
 * (docs/03), never a raw float or a second string field the spec doesn't
 * define.
 */
class DistanceBucketer
{
    public static function bucketKm(float $km): int
    {
        if ($km < 1) {
            return 0;
        }

        if ($km <= 30) {
            return (int) round($km);
        }

        return (int) (round($km / 5) * 5);
    }
}
