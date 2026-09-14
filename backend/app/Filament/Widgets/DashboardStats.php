<?php

namespace App\Filament\Widgets;

use App\Enums\ReportStatus;
use App\Enums\UserStatus;
use App\Models\Message;
use App\Models\Report;
use App\Models\User;
use App\Models\UserMatch;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

/**
 * docs/01-technical-specification.md §19 "Dashboard: total/active/new
 * users, matches, messages, reports, premium users, revenue." Premium
 * users/revenue are deliberately not stat cards here — the `subscriptions`
 * table doesn't exist yet (Phase 2, docs/04 item "Subscription plans");
 * showing a fake "0" for either would look like a working feature rather
 * than an unbuilt one. Revisit when Phase 2 lands.
 */
class DashboardStats extends StatsOverviewWidget
{
    protected function getStats(): array
    {
        return [
            Stat::make('Total users', User::query()->count()),
            Stat::make('Active users', User::query()->where('status', UserStatus::Active)->count()),
            Stat::make('New users (7d)', User::query()->where('created_at', '>=', now()->subDays(7))->count()),
            Stat::make('Matches', UserMatch::query()->count()),
            Stat::make('Messages', Message::query()->count()),
            Stat::make('Pending reports', Report::query()->where('status', ReportStatus::Pending)->count())
                ->color(Report::query()->where('status', ReportStatus::Pending)->exists() ? 'warning' : 'success'),
        ];
    }
}
