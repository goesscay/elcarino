<?php

namespace App\Filament\Resources\Users\Pages;

use App\Filament\Resources\Users\UserResource;
use Filament\Resources\Pages\ListRecords;

/**
 * No CreateAction — see UserResource's doc comment (no Create page; admin
 * accounts don't create user accounts).
 */
class ListUsers extends ListRecords
{
    protected static string $resource = UserResource::class;
}
