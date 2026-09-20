<?php

namespace App\Filament\Resources\VerificationRequests;

use App\Filament\Resources\VerificationRequests\Pages\ListVerificationRequests;
use App\Filament\Resources\VerificationRequests\Tables\VerificationRequestsTable;
use App\Models\VerificationRequest;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

/**
 * docs/01 §19 "Moderation: ... verification review" (open decision #22): the
 * queue of selfies the matcher couldn't approve on its own. List only — no
 * create/edit/view pages: requests are created by users through the mobile API,
 * and the reviewer's whole job is the approve/reject row actions.
 */
class VerificationRequestResource extends Resource
{
    protected static ?string $model = VerificationRequest::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedShieldCheck;

    protected static ?string $modelLabel = 'verification request';

    protected static ?string $navigationLabel = 'Verification';

    protected static ?int $navigationSort = 3;

    public static function getNavigationBadge(): ?string
    {
        $waiting = VerificationRequest::query()->where('status', 'pending')->count();

        return $waiting > 0 ? (string) $waiting : null;
    }

    public static function table(Table $table): Table
    {
        return VerificationRequestsTable::configure($table);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListVerificationRequests::route('/'),
        ];
    }
}
