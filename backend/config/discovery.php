<?php

return [

    'default_per_page' => 20,
    'max_per_page' => 50,

    // Upper bound on rows pulled from SQL before the PHP-side Haversine
    // filter/sort runs (docs/02's "geohash + bounding-box... revisit only if
    // it becomes a bottleneck" — this is the even-simpler-than-that Phase 1
    // starting point: no geo filtering in SQL at all, just a scan cap so one
    // request can't force an unbounded table scan as the user base grows).
    'candidate_scan_limit' => 500,

    // Phase 2 item 3 / open decision #14 ("one boost mechanic assumed —
    // visibility window; frequency/limits TBD"): this is the "visibility
    // window" length. Nothing in /docs states a duration — 30 minutes
    // matches the common industry convention (documented here, not asked
    // about, same tier as OTP_TTL_SECONDS/signed-URL TTLs elsewhere in this
    // app: an implementation default, not a business figure like pricing).
    // *How many* boosts a plan grants per month is a genuine entitlement
    // value (`subscription_plans.entitlements.boosts_per_month`), not this
    // constant.
    'boost_duration_minutes' => 30,

];
