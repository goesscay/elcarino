<?php

namespace App\Filament\Resources\Payments\Tables;

use App\Enums\PaymentStatus;
use App\Models\Payment;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class PaymentsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')->label('ID')->sortable(),
                TextColumn::make('user_label')
                    ->label('User')
                    ->state(fn (Payment $record) => $record->user?->email ?? $record->user?->phone ?? "user#{$record->user_id}"),
                TextColumn::make('amount')
                    ->label('Amount')
                    ->state(fn (Payment $record) => sprintf('%s %.2f', $record->currency, $record->amount_cents / 100)),
                TextColumn::make('status')->badge(),
                TextColumn::make('provider_reference')->label('Provider ref')->copyable()->toggleable(),
                TextColumn::make('subscription_id')->label('Subscription')->placeholder('—'),
                TextColumn::make('created_at')->dateTime()->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('status')->options(array_column(PaymentStatus::cases(), 'value', 'value')),
            ]);
    }
}
