<?php

namespace App\Filament\Resources\Subscriptions\Tables;

use App\Enums\SubscriptionStatus;
use App\Models\Subscription;
use App\Services\Admin\AuditLogger;
use App\Services\Subscriptions\SubscriptionService;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;

class SubscriptionsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('user_label')
                    ->label('User')
                    ->state(fn (Subscription $record) => $record->user?->email ?? $record->user?->phone ?? "user#{$record->user_id}"),
                TextColumn::make('plan.name')->label('Plan'),
                TextColumn::make('status')->badge(),
                TextColumn::make('provider')->badge(),
                TextColumn::make('started_at')->dateTime()->sortable(),
                TextColumn::make('ends_at')->dateTime()->sortable(),
                TextColumn::make('provider_subscription_id')->label('Provider ref')->copyable()->toggleable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('status')->options(array_column(SubscriptionStatus::cases(), 'value', 'value')),
            ])
            ->recordActions([
                self::cancelAction(),
            ]);
    }

    public static function cancelAction(): Action
    {
        return Action::make('cancel')
            ->label('Cancel')
            ->icon('heroicon-o-x-circle')
            ->color('danger')
            ->visible(fn (Subscription $record): bool => $record->status === SubscriptionStatus::Active)
            ->requiresConfirmation()
            ->modalDescription('Ends this subscription immediately — the same as the user cancelling it themselves.')
            ->action(function (Subscription $record): void {
                Gate::authorize('cancel', $record);

                $before = ['status' => $record->status->value];
                app(SubscriptionService::class)->cancel(Auth::user(), $record);
                // Not inside SubscriptionService itself: that method is
                // shared with the user's own self-service cancel (mobile
                // POST /subscriptions/cancel), which must never write an
                // "admin action" audit row — only this admin-triggered path
                // should.
                app(AuditLogger::class)->record(Auth::user(), 'subscription.canceled', $record, $before, ['status' => 'canceled']);

                Notification::make()->title('Subscription canceled')->success()->send();
            });
    }
}
