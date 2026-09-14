<?php

namespace App\Enums;

/**
 * subscriptions.provider. `Other` exists for schema completeness only
 * (open decision #27) — StoreSubscriptionRequest never accepts it as
 * client input, since nothing implements a verifier/gateway for it.
 */
enum SubscriptionProvider: string
{
    case AppStore = 'app_store';
    case PlayStore = 'play_store';
    case Stripe = 'stripe';
    case Other = 'other';
}
