<?php

namespace App\Filament\Resources\Users;

use App\Filament\Resources\Users\Pages\ListUsers;
use App\Filament\Resources\Users\Pages\ViewUser;
use App\Filament\Resources\Users\Schemas\UserInfolist;
use App\Filament\Resources\Users\Tables\UsersTable;
use App\Models\User;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\SoftDeletingScope;

/**
 * docs/01-technical-specification.md §19: "User management: search, view,
 * suspend, ban, delete." No Create/Edit page — admin accounts don't create
 * user accounts (they sign up through the app), and nothing in the spec
 * calls for admins hand-editing arbitrary profile fields; suspend/ban/
 * delete are the only mutations, and they're custom table/header actions
 * (UsersTable) that go through AccountModerationService, not a generic
 * form-backed EditRecord page.
 */
class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUsers;

    protected static ?int $navigationSort = 1;

    public static function infolist(Schema $schema): Schema
    {
        return UserInfolist::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return UsersTable::configure($table);
    }

    public static function getGloballySearchableAttributes(): array
    {
        return ['email', 'phone', 'profile.display_name'];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListUsers::route('/'),
            'view' => ViewUser::route('/{record}'),
        ];
    }

    /**
     * Suspended/banned users are ordinary (not soft-deleted) rows, so the
     * default query already finds them — this override only matters for
     * opening a *deleted* user's own record directly, which the resource's
     * TrashedFilter-driven list otherwise can't reach via the record link.
     */
    public static function getRecordRouteBindingEloquentQuery(): Builder
    {
        return parent::getRecordRouteBindingEloquentQuery()
            ->withoutGlobalScopes([
                SoftDeletingScope::class,
            ]);
    }
}
