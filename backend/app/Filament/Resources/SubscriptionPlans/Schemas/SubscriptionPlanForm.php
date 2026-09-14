<?php

namespace App\Filament\Resources\SubscriptionPlans\Schemas;

use App\Enums\BillingInterval;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

/**
 * Phase 2 item 5 ("Subscription management in admin panel") — the
 * open-decision #12 ("pricing — not set") gap this closes: pricing was
 * previously only ever seedable via `SubscriptionPlanSeeder`'s explicitly-
 * commented placeholder. It's real admin-entered data now, still never a
 * value this app invents on its own.
 */
class SubscriptionPlanForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Plan')
                ->columns(2)
                ->schema([
                    TextInput::make('name')->required()->maxLength(255),
                    TextInput::make('currency')
                        ->required()
                        ->maxLength(3)
                        ->minLength(3)
                        ->alpha()
                        // No ->uppercase() — that's a real-input-mask method
                        // on other Filament components, not TextInput in
                        // this version (confirmed live: BadMethodCallException).
                        // Normalized on save instead.
                        ->dehydrateStateUsing(fn (?string $state): ?string => $state === null ? null : strtoupper($state))
                        ->helperText('ISO 4217, e.g. USD'),
                    TextInput::make('price_cents')
                        ->label('Price (cents)')
                        ->required()
                        ->numeric()
                        ->minValue(0)
                        ->helperText('Integer minor units — 999 = $9.99. Never a float (docs/02).'),
                    Select::make('billing_interval')
                        ->required()
                        ->options(array_column(BillingInterval::cases(), 'name', 'value')),
                    Toggle::make('is_active')
                        ->label('Active')
                        ->helperText('Inactive plans stop appearing to new subscribers; existing subscribers on this plan are unaffected.')
                        ->default(true),
                ]),
            Section::make('Entitlements')
                ->description('The only keys anything in this app reads — see TransformsEntitlements\' own doc comment before adding a fifth.')
                ->columns(2)
                ->schema([
                    Toggle::make('entitlement_unlimited_likes')->label('Unlimited likes'),
                    Toggle::make('entitlement_advanced_filters')->label('Advanced filters (religion/politics)'),
                    Toggle::make('entitlement_unmatched_messaging')->label('Unmatched messaging'),
                    TextInput::make('entitlement_boosts_per_month')
                        ->label('Boosts per month')
                        ->required()
                        ->numeric()
                        ->minValue(0)
                        ->default(0),
                ]),
        ]);
    }
}
