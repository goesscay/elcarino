<?php

namespace App\Filament\Resources\Subscriptions;

use App\Filament\Resources\Subscriptions\Pages\ListSubscriptions;
use App\Filament\Resources\Subscriptions\Tables\SubscriptionsTable;
use App\Models\Subscription;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use UnitEnum;

/**
 * Phase 2 item 5. List-only — no Create (subscriptions are only ever
 * created by SubscriptionService, from a real purchase or webhook) and no
 * Edit form (status changes go through the "Cancel" table action, which
 * calls that same service, not a raw field edit). Admin-only — docs/06 §3.3:
 * "Moderators: ... cannot touch subscription/payment data" — enforced by
 * SubscriptionPolicy, not just by hiding the nav item.
 */
class SubscriptionResource extends Resource
{
    protected static ?string $model = Subscription::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCreditCard;

    protected static string|UnitEnum|null $navigationGroup = 'Billing';

    public static function table(Table $table): Table
    {
        return SubscriptionsTable::configure($table);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListSubscriptions::route('/'),
        ];
    }
}
