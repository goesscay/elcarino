<?php

namespace App\Filament\Resources\SubscriptionPlans\Concerns;

/**
 * `subscription_plans.entitlements` is one JSON column, but a generic
 * key-value form field would treat every value as a string — wrong for the
 * three booleans here, and error-prone for admin-typed keys the app would
 * silently never read. These are the *only* four keys anything in this app
 * actually checks (`User::entitlement($key)` call sites: `advanced_filters`
 * — DiscoveryFeedService/PreferenceController, `boosts_per_month` —
 * BoostService; `unlimited_likes`/`unmatched_messaging` are read by the
 * mobile Premium screen's entitlement bullet list, not gated server-side
 * key-by-key). Adding a fifth entitlement the app actually reads means
 * adding a field here too — flagged, not a place this silently drifts out
 * of sync.
 */
trait TransformsEntitlements
{
    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    protected function expandEntitlements(array $data): array
    {
        $entitlements = $data['entitlements'] ?? [];

        $data['entitlement_unlimited_likes'] = (bool) ($entitlements['unlimited_likes'] ?? false);
        $data['entitlement_advanced_filters'] = (bool) ($entitlements['advanced_filters'] ?? false);
        $data['entitlement_unmatched_messaging'] = (bool) ($entitlements['unmatched_messaging'] ?? false);
        $data['entitlement_boosts_per_month'] = (int) ($entitlements['boosts_per_month'] ?? 0);

        return $data;
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    protected function collapseEntitlements(array $data): array
    {
        $data['entitlements'] = [
            'unlimited_likes' => (bool) ($data['entitlement_unlimited_likes'] ?? false),
            'advanced_filters' => (bool) ($data['entitlement_advanced_filters'] ?? false),
            'unmatched_messaging' => (bool) ($data['entitlement_unmatched_messaging'] ?? false),
            'boosts_per_month' => (int) ($data['entitlement_boosts_per_month'] ?? 0),
        ];

        unset(
            $data['entitlement_unlimited_likes'],
            $data['entitlement_advanced_filters'],
            $data['entitlement_unmatched_messaging'],
            $data['entitlement_boosts_per_month'],
        );

        return $data;
    }
}
