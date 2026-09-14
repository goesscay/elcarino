<?php

namespace App\Enums;

/**
 * subscriptions.status. `expired` is written by a future scheduled job
 * (nothing in this feature writes it yet — a subscription's `ends_at`
 * passing is what `User::currentSubscription()` actually checks, so an
 * un-swept `active` row past its `ends_at` still correctly stops granting
 * access; the job would only tidy the status label itself). `past_due` is
 * written from a Stripe `invoice.payment_failed` webhook event.
 */
enum SubscriptionStatus: string
{
    case Active = 'active';
    case Canceled = 'canceled';
    case Expired = 'expired';
    case PastDue = 'past_due';
}
