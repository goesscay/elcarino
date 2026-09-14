<?php

namespace App\Filament\Resources\Users\Pages;

use App\Filament\Resources\Users\Tables\UsersTable;
use App\Filament\Resources\Users\UserResource;
use Filament\Resources\Pages\ViewRecord;

/**
 * No EditAction — this resource has no Edit page (see UserResource's doc
 * comment). The same suspend/reinstate/ban/delete actions the list table
 * uses are reused here verbatim, not re-implemented, so there's exactly one
 * place each action's visibility/authorization rule lives.
 */
class ViewUser extends ViewRecord
{
    protected static string $resource = UserResource::class;

    protected function getHeaderActions(): array
    {
        return [
            UsersTable::suspendAction(),
            UsersTable::reinstateAction(),
            UsersTable::banAction(),
            UsersTable::deleteAction(),
        ];
    }
}
