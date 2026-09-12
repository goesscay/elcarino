<?php

return [

    // Signed profile-photo URL lifetime — docs/06-security-architecture.md §6
    // ("longer but still bounded for profile photos" vs. chat media).
    'signed_url_ttl_minutes' => env('MEDIA_SIGNED_URL_TTL_MINUTES', 15),

    // Server-side upload limits — §6 "max dimensions, max file size".
    'max_photo_size_kb' => env('MEDIA_MAX_PHOTO_SIZE_KB', 8192),
    'max_photo_dimension' => env('MEDIA_MAX_PHOTO_DIMENSION', 4096),

    // docs/07-ui-ux-design.md §3.1 — Photos screen: "Grid of 6 slots".
    'max_photos_per_profile' => 6,

    // docs/07-ui-ux-design.md §3.1 — Prompts screen: "Pick 3 prompts".
    'max_prompts_per_profile' => 3,

];
