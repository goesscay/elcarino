<?php

namespace App\Filament\Resources\VerificationRequests\Pages;

use App\Filament\Resources\VerificationRequests\VerificationRequestResource;
use Filament\Resources\Pages\ListRecords;

/**
 * No CreateAction — see VerificationRequestResource's doc comment.
 */
class ListVerificationRequests extends ListRecords
{
    protected static string $resource = VerificationRequestResource::class;
}
