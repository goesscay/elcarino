<?php

namespace App\Services\Discovery;

use App\Enums\BoostSource;
use App\Models\Boost;
use App\Models\User;

/**
 * Phase 2 item 3 / open decision #14 ("one boost mechanic assumed —
 * visibility window; frequency/limits TBD"). "Frequency/limits" is
 * concretely `subscription_plans.entitlements.boosts_per_month` — a real
 * entitlement value, not invented here; the *duration* of the window is
 * `config('discovery.boost_duration_minutes')`, an implementation default
 * (see that config file's own doc comment on why that's not a business
 * decision the same way pricing is).
 */
class BoostService
{
    /**
     * @throws BoostUnavailableException
     */
    public function activate(User $user): Boost
    {
        if ($user->activeBoost() !== null) {
            throw BoostUnavailableException::alreadyActive();
        }

        $limit = $user->entitlement('boosts_per_month');
        if (! is_int($limit) || $limit < 1) {
            throw BoostUnavailableException::noEntitlement();
        }

        $usedThisMonth = $user->boosts()
            ->where('source', BoostSource::SubscriptionPerk)
            ->where('created_at', '>=', now()->startOfMonth())
            ->count();

        if ($usedThisMonth >= $limit) {
            throw BoostUnavailableException::limitReached($limit);
        }

        return $user->boosts()->create([
            'starts_at' => now(),
            'ends_at' => now()->addMinutes(config('discovery.boost_duration_minutes')),
            'source' => BoostSource::SubscriptionPerk,
        ]);
    }

    /**
     * @return array{active: bool, ends_at: ?string, used_this_month: int, limit: int|false}
     */
    public function status(User $user): array
    {
        $active = $user->activeBoost();
        $limit = $user->entitlement('boosts_per_month');

        return [
            'active' => $active !== null,
            'ends_at' => $active?->ends_at->toIso8601String(),
            'used_this_month' => $user->boosts()
                ->where('source', BoostSource::SubscriptionPerk)
                ->where('created_at', '>=', now()->startOfMonth())
                ->count(),
            'limit' => is_int($limit) ? $limit : false,
        ];
    }
}
