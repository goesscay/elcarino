<?php

return [

    // Signed profile-photo URL lifetime — docs/06-security-architecture.md §6
    // ("longer but still bounded for profile photos" vs. chat media).
    'signed_url_ttl_minutes' => env('MEDIA_SIGNED_URL_TTL_MINUTES', 15),

    // Server-side upload limits — §6 "max dimensions, max file size".
    'max_photo_size_kb' => env('MEDIA_MAX_PHOTO_SIZE_KB', 8192),
    'max_photo_dimension' => env('MEDIA_MAX_PHOTO_DIMENSION', 4096),

    // Chat media (Phase 3 item 1, voice notes) gets a shorter-lived signed
    // URL than profile photos — docs/06-security-architecture.md §6: "minutes,
    // shorter than profile photos' longer-but-bounded TTL" — because it's
    // fetched once by the recipient's device shortly after send, not
    // re-fetched by browsers/crawlers over a session the way a profile photo
    // is.
    'chat_media_signed_url_ttl_minutes' => env('MEDIA_CHAT_SIGNED_URL_TTL_MINUTES', 5),

    // Voice notes: no duration/size numbers are specified anywhere in /docs
    // (open decision #16's working assumption is just "in scope", not any
    // particular limit) — these are provisional caps in the same spirit as
    // the photo/prompt/interest caps above. Safe to retune.
    'max_voice_note_size_kb' => env('MEDIA_MAX_VOICE_NOTE_SIZE_KB', 5120),
    'max_voice_note_duration_seconds' => env('MEDIA_MAX_VOICE_NOTE_DURATION_SECONDS', 120),

    // docs/07-ui-ux-design.md §3.1 — Photos screen: "Grid of 6 slots".
    'max_photos_per_profile' => 6,

    // docs/07-ui-ux-design.md §3.1 — Prompts screen: "Pick 3 prompts".
    'max_prompts_per_profile' => 3,

    // No count is specified anywhere in /docs for interests — a provisional
    // cap (not one of the 30 tracked decisions) to bound the payload/UI, same
    // spirit as the prompt/photo caps above. Safe to retune.
    'max_interests_per_profile' => 15,

];
