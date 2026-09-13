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

];
