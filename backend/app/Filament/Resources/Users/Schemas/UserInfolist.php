<?php

namespace App\Filament\Resources\Users\Schemas;

use App\Models\User;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class UserInfolist
{
    public static function configure(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Account')
                ->columns(3)
                ->schema([
                    TextEntry::make('id')->label('ID'),
                    TextEntry::make('status')->badge(),
                    TextEntry::make('role')->badge(),
                    TextEntry::make('email')->default('—'),
                    TextEntry::make('phone')->default('—'),
                    TextEntry::make('last_active_at')->label('Last active')->since()->placeholder('Never'),
                    TextEntry::make('created_at')->label('Joined')->dateTime(),
                    TextEntry::make('email_verified_at')->label('Email verified')->dateTime()->placeholder('No'),
                    TextEntry::make('phone_verified_at')->label('Phone verified')->dateTime()->placeholder('No'),
                ]),
            Section::make('Profile')
                ->columns(3)
                ->schema([
                    TextEntry::make('profile.display_name')->label('Display name')->default('— (no profile yet)'),
                    TextEntry::make('profile.gender')->label('Gender')->default('—'),
                    TextEntry::make('profile.birth_date')->label('Birth date')->date()->default('—'),
                ]),
            Section::make('Safety')
                ->description('Reports queue is the "Reports" panel section — this is just a count.')
                ->columns(2)
                ->schema([
                    TextEntry::make('reports_received_count')
                        ->label('Reports received')
                        ->state(fn (User $record): int => $record->reportsReceived()->count()),
                    TextEntry::make('reports_made_count')
                        ->label('Reports made')
                        ->state(fn (User $record): int => $record->reportsMade()->count()),
                ]),
        ]);
    }
}
