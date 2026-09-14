<?php

namespace App\Enums;

enum BoostSource: string
{
    case Purchase = 'purchase';
    case SubscriptionPerk = 'subscription_perk';
}
