<?php

namespace App\Filament\Resources\SubscriptionPlans\Tables;

use Filament\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class SubscriptionPlansTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')->searchable(),
                TextColumn::make('price_cents')
                    ->label('Price')
                    ->formatStateUsing(fn ($record) => sprintf('%s %.2f', $record->currency, $record->price_cents / 100)),
                TextColumn::make('billing_interval')->badge(),
                IconColumn::make('entitlements.unlimited_likes')->label('Likes')->boolean(),
                IconColumn::make('entitlements.advanced_filters')->label('Filters')->boolean(),
                IconColumn::make('entitlements.unmatched_messaging')->label('Messaging')->boolean(),
                TextColumn::make('entitlements.boosts_per_month')->label('Boosts/mo'),
                IconColumn::make('is_active')->boolean(),
                TextColumn::make('subscriptions_count')->label('Subscribers')->counts('subscriptions'),
            ])
            ->defaultSort('created_at', 'desc')
            ->recordActions([
                EditAction::make(),
            ]);
    }
}
