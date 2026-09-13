<?php

namespace Tests\Unit\Services\Geo;

use App\Services\Geo\Geohash;
use PHPUnit\Framework\TestCase;

class GeohashTest extends TestCase
{
    public function test_it_matches_the_well_known_reference_value(): void
    {
        // The standard geohash worked example (Wikipedia, geohash.org):
        // 57.64911, 10.40744 -> "u4pruydqqvj".
        $this->assertSame('u4pruydqqvj', Geohash::encode(57.64911, 10.40744, 11));
    }

    public function test_nearby_points_share_a_prefix(): void
    {
        $a = Geohash::encode(3.1390, 101.6870, 9);
        $b = Geohash::encode(3.1391, 101.6871, 9);

        $this->assertSame(substr($a, 0, 6), substr($b, 0, 6));
    }
}
