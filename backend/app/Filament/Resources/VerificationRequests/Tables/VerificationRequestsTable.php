<?php

namespace App\Filament\Resources\VerificationRequests\Tables;

use App\Enums\VerificationMethod;
use App\Enums\VerificationRejection;
use App\Enums\VerificationStatus;
use App\Models\VerificationRequest;
use App\Services\Admin\VerificationModerationService;
use App\Services\Verification\VerificationException;
use Filament\Actions\Action;
use Filament\Forms\Components\Select;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;

/**
 * The verification review queue (open decision #22). Defaults to the requests
 * waiting for a person; every decision goes through
 * VerificationModerationService, never a raw model update, so it is audited and
 * shares its rules (verified flag, selfie deletion, notification) with the AI
 * path. The reviewer sees *why* it is here (`ai_outcome`/score) — the person
 * never does.
 */
class VerificationRequestsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('user_label')
                    ->label('User')
                    ->state(fn (VerificationRequest $record) => $record->user?->email ?? $record->user?->phone ?? "user#{$record->user_id}"),
                TextColumn::make('method')->badge(),
                TextColumn::make('status')->badge(),
                TextColumn::make('ai_outcome')->label('AI said')->placeholder('—'),
                TextColumn::make('ai_score')->label('AI score')->numeric(1)->placeholder('—'),
                TextColumn::make('pose')
                    ->label('Pose asked')
                    ->formatStateUsing(fn (string $state) => config("verification.poses.{$state}", $state)),
                TextColumn::make('result.reason')->label('Rejected for')->placeholder('—'),
                TextColumn::make('result.reviewer.email')->label('Decided by')->placeholder('—'),
                TextColumn::make('submitted_at')->since()->sortable(),
            ])
            ->defaultSort('submitted_at', 'asc')
            ->filters([
                SelectFilter::make('status')
                    ->options(array_column(VerificationStatus::cases(), 'value', 'value'))
                    ->default(VerificationStatus::Pending->value),
                SelectFilter::make('method')->options(array_column(VerificationMethod::cases(), 'value', 'value')),
            ])
            ->recordActions([
                self::viewSelfieAction(),
                self::approveAction(),
                self::rejectAction(),
            ]);
    }

    private static function awaitingReview(VerificationRequest $record): bool
    {
        return $record->status === VerificationStatus::Pending && $record->method === VerificationMethod::ManualReview;
    }

    /**
     * Shows the selfie through the audited streaming route — the image is never
     * a public URL, and opening it writes `verification.selfie_viewed`.
     */
    public static function viewSelfieAction(): Action
    {
        return Action::make('viewSelfie')
            ->label('View selfie')
            ->icon('heroicon-o-eye')
            ->color('gray')
            ->visible(fn (VerificationRequest $record): bool => $record->selfie_path !== null)
            ->modalHeading('Selfie')
            ->modalContent(fn (VerificationRequest $record) => view('filament.verification.selfie', ['record' => $record]))
            ->modalSubmitAction(false)
            ->modalCancelActionLabel('Close');
    }

    public static function approveAction(): Action
    {
        return Action::make('approve')
            ->label('Approve')
            ->icon('heroicon-o-check-badge')
            ->color('success')
            ->visible(fn (VerificationRequest $record): bool => self::awaitingReview($record))
            ->requiresConfirmation()
            ->modalDescription('Marks the profile verified, notifies the person, and deletes the selfie.')
            ->action(function (VerificationRequest $record): void {
                self::decide(fn () => app(VerificationModerationService::class)->approve(Auth::user(), $record), 'Verification approved');
            });
    }

    public static function rejectAction(): Action
    {
        return Action::make('reject')
            ->label('Reject')
            ->icon('heroicon-o-x-circle')
            ->color('danger')
            ->visible(fn (VerificationRequest $record): bool => self::awaitingReview($record))
            ->schema([
                Select::make('reason')
                    ->label('Reason (the person sees a friendly version of this)')
                    ->options(collect(VerificationRejection::cases())->mapWithKeys(fn ($r) => [$r->value => $r->getLabel()])->all())
                    ->default(VerificationRejection::FaceMismatch->value)
                    ->required(),
            ])
            ->modalDescription('Rejects the request, notifies the person, and deletes the selfie. They can try again.')
            ->action(function (VerificationRequest $record, array $data): void {
                self::decide(
                    fn () => app(VerificationModerationService::class)->reject(Auth::user(), $record, VerificationRejection::from($data['reason'])),
                    'Verification rejected',
                );
            });
    }

    /**
     * Two reviewers can open the same row; the second one to click finds it
     * already decided. That is a normal outcome to report, not a server error.
     */
    private static function decide(callable $decision, string $successTitle): void
    {
        try {
            $decision();
            Notification::make()->title($successTitle)->success()->send();
        } catch (VerificationException $e) {
            Notification::make()->title($e->getMessage())->warning()->send();
        }
    }
}
