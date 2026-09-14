<?php

namespace App\Filament\Resources\Subscriptions\Pages;

use App\Filament\Resources\Subscriptions\SubscriptionResource;
use Filament\Resources\Pages\ListRecords;

/**
 * No CreateAction — see SubscriptionResource's doc comment.
 */
class ListSubscriptions extends ListRecords
{
    protected static string $resource = SubscriptionResource::class;
}
