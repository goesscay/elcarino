<?php

namespace App\Filament\Resources\Reports\Tables;

use App\Enums\ReportCategory;
use App\Enums\ReportStatus;
use App\Enums\UserStatus;
use App\Models\Report;
use App\Services\Admin\AccountModerationService;
use App\Services\Admin\ReportModerationService;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;

/**
 * docs/01-technical-specification.md §19 "Moderation: reports queue" +
 * docs/06-security-architecture.md §3.3 (moderators may work this queue,
 * same as admins). No create/edit/delete here — reports are only ever
 * created by users through the mobile API (Phase 1 item 10); this panel
 * only changes a report's disposition, via ReportModerationService, never
 * a raw model update.
 */
class ReportsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('reporter_label')
                    ->label('Reporter')
                    ->state(fn (Report $record) => $record->reporter?->email ?? $record->reporter?->phone ?? "user#{$record->reporter_id}"),
                TextColumn::make('reported_label')
                    ->label('Reported')
                    ->state(fn (Report $record) => $record->reported?->email ?? $record->reported?->phone ?? "user#{$record->reported_id}"),
                TextColumn::make('category')->badge(),
                TextColumn::make('description')->limit(60)->wrap()->placeholder('—')->toggleable(),
                TextColumn::make('status')->badge(),
                TextColumn::make('reviewer.email')->label('Reviewed by')->placeholder('—'),
                TextColumn::make('reviewed_at')->since()->placeholder('—'),
                TextColumn::make('created_at')->label('Reported')->since()->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('status')->options(array_column(ReportStatus::cases(), 'value', 'value')),
                SelectFilter::make('category')->options(array_column(ReportCategory::cases(), 'value', 'value')),
            ])
            ->recordActions([
                self::actionedAction(),
                self::dismissAction(),
                self::suspendReportedUserAction(),
            ]);
    }

    public static function actionedAction(): Action
    {
        return Action::make('actioned')
            ->label('Mark actioned')
            ->icon('heroicon-o-check-circle')
            ->color('danger')
            ->visible(fn (Report $record): bool => in_array($record->status, [ReportStatus::Pending, ReportStatus::Reviewing], true))
            ->requiresConfirmation()
            ->action(function (Report $record): void {
                app(ReportModerationService::class)->action(Auth::user(), $record);

                Notification::make()->title('Report marked actioned')->success()->send();
            });
    }

    public static function dismissAction(): Action
    {
        return Action::make('dismiss')
            ->label('Dismiss')
            ->icon('heroicon-o-x-circle')
            ->color('gray')
            ->visible(fn (Report $record): bool => in_array($record->status, [ReportStatus::Pending, ReportStatus::Reviewing], true))
            ->requiresConfirmation()
            ->action(function (Report $record): void {
                app(ReportModerationService::class)->dismiss(Auth::user(), $record);

                Notification::make()->title('Report dismissed')->success()->send();
            });
    }

    /**
     * A one-click "reports queue" -> "user management" bridge: the natural
     * next step after a report is confirmed legitimate. Marks the report
     * actioned *and* suspends the reported account in one action — both
     * still go through their own services (so both are audit-logged, each
     * under its own action name), not a bespoke third code path.
     */
    public static function suspendReportedUserAction(): Action
    {
        return Action::make('suspendReportedUser')
            ->label('Suspend reported user')
            ->icon('heroicon-o-pause-circle')
            ->color('warning')
            ->visible(fn (Report $record): bool => $record->reported !== null
                && $record->reported->status === UserStatus::Active
                && in_array($record->status, [ReportStatus::Pending, ReportStatus::Reviewing], true))
            ->requiresConfirmation()
            ->modalDescription('Suspends the reported account immediately and marks this report actioned.')
            ->action(function (Report $record): void {
                app(AccountModerationService::class)->suspend(Auth::user(), $record->reported, "Suspended from report #{$record->id}");
                app(ReportModerationService::class)->action(Auth::user(), $record);

                Notification::make()->title('User suspended and report actioned')->success()->send();
            });
    }
}
