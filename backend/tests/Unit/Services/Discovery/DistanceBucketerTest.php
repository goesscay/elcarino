<?php

namespace Tests\Unit\Services\Discovery;

use App\Services\Discovery\DistanceBucketer;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class DistanceBucketerTest extends TestCase
{
    /**
     * docs/06-security-architecture.md §4: "< 1 km -> 0 (the client renders
     * 'less than 1 km away'); otherwise rounded to the nearest km (or
     * nearest 5 km beyond 30 km)."
     */
    public static function bucketCases(): array
    {
        return [
            'under 1km rounds to the sentinel 0' => [0.4, 0],
            'exactly at the sentinel boundary' => [0.99, 0],
            'a normal in-range distance rounds to the nearest km' => [4.4, 4],
            'rounds up within range' => [4.6, 5],
            'right at the 30km tier boundary' => [30.0, 30],
            'just beyond 30km rounds to the nearest 5km' => [31.0, 30],
            'further beyond 30km rounds up to the nearest 5km' => [33.0, 35],
            'far beyond 30km' => [187.0, 185],
        ];
    }

    #[DataProvider('bucketCases')]
    public function test_it_buckets_distance_per_the_documented_rule(float $km, int $expected): void
    {
        $this->assertSame($expected, DistanceBucketer::bucketKm($km));
    }
}
