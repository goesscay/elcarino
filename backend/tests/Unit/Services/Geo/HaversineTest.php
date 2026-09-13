<?php

namespace Tests\Unit\Services\Geo;

use App\Services\Geo\Haversine;
use PHPUnit\Framework\TestCase;

class HaversineTest extends TestCase
{
    public function test_distance_between_the_same_point_is_zero(): void
    {
        $this->assertSame(0.0, Haversine::kilometers(3.139, 101.687, 3.139, 101.687));
    }

    public function test_kuala_lumpur_to_male_is_roughly_correct(): void
    {
        // Kuala Lumpur (3.139, 101.687) to Malé (4.1755, 73.5093) — the two
        // launch markets docs/00 names first. Great-circle distance is
        // ~3,129 km (verified against an independent Haversine calculator,
        // not just this implementation agreeing with itself).
        $km = Haversine::kilometers(3.139, 101.687, 4.1755, 73.5093);

        $this->assertEqualsWithDelta(3129, $km, 5);
    }
}
