<?php

namespace App\Services\Geo;

/**
 * Great-circle distance in kilometers. Computed in PHP, not SQL — portable
 * across SQLite (local) and PostgreSQL (staging/prod) with no
 * database-specific trig functions, per CLAUDE.md's backend conventions.
 */
class Haversine
{
    private const EARTH_RADIUS_KM = 6371.0;

    public static function kilometers(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $latDelta = deg2rad($lat2 - $lat1);
        $lonDelta = deg2rad($lon2 - $lon1);

        $a = sin($latDelta / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($lonDelta / 2) ** 2;

        return self::EARTH_RADIUS_KM * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
