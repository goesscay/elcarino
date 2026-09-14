<?php

namespace Tests\Unit\Filament;

use App\Filament\Resources\SubscriptionPlans\Concerns\TransformsEntitlements;
use PHPUnit\Framework\TestCase;

class TransformsEntitlementsTest extends TestCase
{
    private function subject(): object
    {
        return new class
        {
            use TransformsEntitlements;

            public function expand(array $data): array
            {
                return $this->expandEntitlements($data);
            }

            public function collapse(array $data): array
            {
                return $this->collapseEntitlements($data);
            }
        };
    }

    public function test_expand_reads_all_four_known_keys(): void
    {
        $expanded = $this->subject()->expand([
            'name' => 'Gold',
            'entitlements' => [
                'unlimited_likes' => true,
                'advanced_filters' => false,
                'unmatched_messaging' => true,
                'boosts_per_month' => 3,
            ],
        ]);

        $this->assertSame('Gold', $expanded['name']);
        $this->assertTrue($expanded['entitlement_unlimited_likes']);
        $this->assertFalse($expanded['entitlement_advanced_filters']);
        $this->assertTrue($expanded['entitlement_unmatched_messaging']);
        $this->assertSame(3, $expanded['entitlement_boosts_per_month']);
    }

    public function test_expand_defaults_missing_keys_to_false_or_zero(): void
    {
        $expanded = $this->subject()->expand(['entitlements' => []]);

        $this->assertFalse($expanded['entitlement_unlimited_likes']);
        $this->assertFalse($expanded['entitlement_advanced_filters']);
        $this->assertFalse($expanded['entitlement_unmatched_messaging']);
        $this->assertSame(0, $expanded['entitlement_boosts_per_month']);
    }

    public function test_collapse_assembles_the_entitlements_array_and_strips_the_loose_keys(): void
    {
        $collapsed = $this->subject()->collapse([
            'name' => 'Gold',
            'entitlement_unlimited_likes' => true,
            'entitlement_advanced_filters' => false,
            'entitlement_unmatched_messaging' => true,
            'entitlement_boosts_per_month' => '2',
        ]);

        $this->assertSame('Gold', $collapsed['name']);
        $this->assertSame([
            'unlimited_likes' => true,
            'advanced_filters' => false,
            'unmatched_messaging' => true,
            'boosts_per_month' => 2,
        ], $collapsed['entitlements']);
        $this->assertArrayNotHasKey('entitlement_unlimited_likes', $collapsed);
        $this->assertArrayNotHasKey('entitlement_advanced_filters', $collapsed);
        $this->assertArrayNotHasKey('entitlement_unmatched_messaging', $collapsed);
        $this->assertArrayNotHasKey('entitlement_boosts_per_month', $collapsed);
    }

    public function test_expand_then_collapse_round_trips(): void
    {
        $original = [
            'unlimited_likes' => true,
            'advanced_filters' => true,
            'unmatched_messaging' => false,
            'boosts_per_month' => 5,
        ];

        $subject = $this->subject();
        $roundTripped = $subject->collapse($subject->expand(['entitlements' => $original]));

        $this->assertSame($original, $roundTripped['entitlements']);
    }
}
