<?php

namespace App\Filament\Widgets;

use App\Enums\PaymentStatus;
use App\Enums\ReportStatus;
use App\Enums\SubscriptionStatus;
use App\Enums\UserStatus;
use App\Models\Message;
use App\Models\Payment;
use App\Models\Report;
use App\Models\Subscription;
use App\Models\User;
use App\Models\UserMatch;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

/**
 * docs/01-technical-specification.md §19 "Dashboard: total/active/new
 * users, matches, messages, reports, premium users, revenue." Premium
 * users/revenue were deliberately left out at Phase 1 item 11 — the
 * `subscriptions` table didn't exist yet, and a fake "0" would have looked
 * like a working feature rather than an unbuilt one. Both are real now
 * (Phase 2 item 5).
 *
 * "Revenue" sums `amount_cents` across every succeeded payment regardless
 * of `currency` — correct today only because every plan this app has ever
 * seeded/created uses USD; a genuinely multi-currency deployment would need
 * per-currency totals instead of one summed number. Flagged, not silently
 * wrong: revisit if/when a non-USD plan is ever created.
 */
class DashboardStats extends StatsOverviewWidget
{
    protected function getStats(): array
    {
        $revenueCents = Payment::query()->where('status', PaymentStatus::Succeeded)->sum('amount_cents');

        return [
            Stat::make('Total users', User::query()->count()),
            Stat::make('Active users', User::query()->where('status', UserStatus::Active)->count()),
            Stat::make('New users (7d)', User::query()->where('created_at', '>=', now()->subDays(7))->count()),
            Stat::make('Matches', UserMatch::query()->count()),
            Stat::make('Messages', Message::query()->count()),
            Stat::make('Pending reports', Report::query()->where('status', ReportStatus::Pending)->count())
                ->color(Report::query()->where('status', ReportStatus::Pending)->exists() ? 'warning' : 'success'),
            Stat::make(
                'Premium users',
                Subscription::query()
                    ->where('status', SubscriptionStatus::Active)
                    ->where('ends_at', '>', now())
                    ->distinct('user_id')
                    ->count('user_id'),
            ),
            Stat::make('Revenue', '$'.number_format($revenueCents / 100, 2)),
        ];
    }
}
