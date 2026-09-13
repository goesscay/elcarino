<?php

namespace App\Services\Geo;

/**
 * Standard geohash base32 encoding (Niemeyer geohash — the same algorithm
 * Wikipedia/most libraries implement). Stored per docs/02-database-schema.md
 * (`user_locations.geohash`, indexed) for the future geohash-bucketed
 * proximity query docs/02's indexing notes describe as the eventual Phase 1
 * approach — not used for filtering yet (see DiscoveryFeedService), only
 * computed and persisted now so that optimization is a query change later,
 * not a backfill.
 */
class Geohash
{
    private const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

    public static function encode(float $latitude, float $longitude, int $precision = 9): string
    {
        $latRange = [-90.0, 90.0];
        $lonRange = [-180.0, 180.0];
        $geohash = '';
        $isEven = true;
        $bit = 0;
        $ch = 0;

        while (strlen($geohash) < $precision) {
            if ($isEven) {
                $mid = ($lonRange[0] + $lonRange[1]) / 2;
                if ($longitude >= $mid) {
                    $ch |= (1 << (4 - $bit));
                    $lonRange[0] = $mid;
                } else {
                    $lonRange[1] = $mid;
                }
            } else {
                $mid = ($latRange[0] + $latRange[1]) / 2;
                if ($latitude >= $mid) {
                    $ch |= (1 << (4 - $bit));
                    $latRange[0] = $mid;
                } else {
                    $latRange[1] = $mid;
                }
            }

            $isEven = ! $isEven;

            if ($bit < 4) {
                $bit++;
            } else {
                $geohash .= self::BASE32[$ch];
                $bit = 0;
                $ch = 0;
            }
        }

        return $geohash;
    }
}
