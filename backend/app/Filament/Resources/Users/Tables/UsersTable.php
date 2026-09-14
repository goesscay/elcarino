<?php

namespace App\Filament\Resources\Users\Tables;

use App\Enums\UserRole;
use App\Enums\UserStatus;
use App\Models\User;
use App\Services\Admin\AccountModerationService;
use Filament\Actions\Action;
use Filament\Actions\ViewAction;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TrashedFilter;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;

/**
 * docs/01-technical-specification.md §19 "User management: search, view,
 * suspend, ban, delete." No bulk actions here on purpose: every status
 * change must go through AccountModerationService (token revoke + audit
 * log, docs/06 §8/§9) — a native Filament bulk-delete/etc. action would
 * write straight to the model and silently bypass both.
 */
class UsersTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('profile.display_name')->label('Name')->searchable()->default('—'),
                TextColumn::make('email')->searchable()->copyable()->default('—'),
                TextColumn::make('phone')->searchable()->copyable()->default('—'),
                TextColumn::make('status')->badge()->sortable(),
                TextColumn::make('role')->badge()->sortable(),
                TextColumn::make('last_active_at')->label('Last active')->since()->sortable()->placeholder('Never'),
                TextColumn::make('created_at')->label('Joined')->since()->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('status')->options(
                    array_column(UserStatus::cases(), 'value', 'value')
                ),
                SelectFilter::make('role')->options(
                    array_column(UserRole::cases(), 'value', 'value')
                ),
                TrashedFilter::make(),
            ])
            ->recordActions([
                ViewAction::make(),
                self::suspendAction(),
                self::reinstateAction(),
                self::banAction(),
                self::deleteAction(),
            ]);
    }

    public static function suspendAction(): Action
    {
        return Action::make('suspend')
            ->label('Suspend')
            ->icon('heroicon-o-pause-circle')
            ->color('warning')
            ->visible(fn (User $record): bool => $record->status === UserStatus::Active)
            ->requiresConfirmation()
            ->schema([
                Textarea::make('reason')->label('Reason (internal, audit log only)')->rows(2),
            ])
            ->action(function (User $record, array $data): void {
                app(AccountModerationService::class)->suspend(Auth::user(), $record, $data['reason'] ?? null);

                Notification::make()->title('User suspended')->success()->send();
            });
    }

    public static function reinstateAction(): Action
    {
        return Action::make('reinstate')
            ->label('Reinstate')
            ->icon('heroicon-o-play-circle')
            ->color('success')
            ->visible(fn (User $record): bool => $record->status === UserStatus::Suspended)
            ->requiresConfirmation()
            ->action(function (User $record): void {
                app(AccountModerationService::class)->reinstate(Auth::user(), $record);

                Notification::make()->title('User reinstated')->success()->send();
            });
    }

    /**
     * docs/06-security-architecture.md §3.3: "Moderators: ... user suspend
     * only. Cannot delete users." Ban isn't named alongside suspend in that
     * sentence, so it's treated as admin-only too — the same escalation
     * tier as delete, both permanent/destructive in a way plain suspend
     * isn't. Enforced twice: hidden from moderators here, *and* re-checked
     * inside the action closure (fail closed) so hiding a button is never
     * the actual control.
     */
    public static function banAction(): Action
    {
        return Action::make('ban')
            ->label('Ban')
            ->icon('heroicon-o-no-symbol')
            ->color('danger')
            ->visible(fn (User $record): bool => Auth::user()->isAdmin() && $record->status !== UserStatus::Banned)
            ->requiresConfirmation()
            ->schema([
                Textarea::make('reason')->label('Reason (internal, audit log only)')->rows(2),
            ])
            ->action(function (User $record, array $data): void {
                Gate::authorize('banUsers');

                app(AccountModerationService::class)->ban(Auth::user(), $record, $data['reason'] ?? null);

                Notification::make()->title('User banned')->success()->send();
            });
    }

    public static function deleteAction(): Action
    {
        return Action::make('delete')
            ->label('Delete')
            ->icon('heroicon-o-trash')
            ->color('danger')
            ->visible(fn (User $record): bool => Auth::user()->isAdmin() && $record->status !== UserStatus::Deleted)
            ->requiresConfirmation()
            ->modalDescription('This soft-deletes the account and revokes every session immediately. This cannot be undone from the panel.')
            ->schema([
                Textarea::make('reason')->label('Reason (internal, audit log only)')->rows(2),
            ])
            ->action(function (User $record, array $data): void {
                Gate::authorize('deleteUsers');

                app(AccountModerationService::class)->delete(Auth::user(), $record, $data['reason'] ?? null);

                Notification::make()->title('User deleted')->success()->send();
            });
    }
}
