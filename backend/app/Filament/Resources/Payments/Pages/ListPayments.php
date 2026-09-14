<?php

namespace App\Filament\Resources\Payments\Pages;

use App\Filament\Resources\Payments\PaymentResource;
use Filament\Resources\Pages\ListRecords;

/**
 * No CreateAction — see PaymentResource's doc comment.
 */
class ListPayments extends ListRecords
{
    protected static string $resource = PaymentResource::class;
}
