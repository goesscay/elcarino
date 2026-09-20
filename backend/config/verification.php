<?php

/*
 * Profile verification (docs/01 §15, open decisions #21-23). Everything a
 * business or legal owner might want to retune lives here, not in code.
 */
return [

    // Which FaceMatcher does the AI check. [TBD-21]: the provider is not
    // chosen. `none` (the default) never approves anything itself — every
    // request goes to the human review queue (#22), which is the safe answer
    // until a real provider is wired. `fake` is for local development and
    // tests only and refuses to boot in production (AppServiceProvider).
    'provider' => env('VERIFICATION_PROVIDER', 'none'),

    // What the `fake` provider reports (matched | not_matched | no_face |
    // inconclusive) and, for `matched`, its score. Local dev only.
    'fake' => [
        'outcome' => env('VERIFICATION_FAKE_OUTCOME', 'matched'),
        'score' => (float) env('VERIFICATION_FAKE_SCORE', 97),
    ],

    // The minimum matcher confidence (0-100) that approves a request with no
    // human in the loop. [TBD-21] A safety number, not an engineering one: too
    // low lets impostors through with a trust badge, too high floods the human
    // queue. 90 is a placeholder to be set from real provider scores. A score
    // below it is *never* an automatic rejection — it goes to a person.
    'approve_threshold' => (float) env('VERIFICATION_APPROVE_THRESHOLD', 90),

    // How many requests one person may start per rolling 24 hours. Bounds
    // guessing the matcher by re-trying selfies. [TBD-21] provisional.
    'max_attempts_per_day' => (int) env('VERIFICATION_MAX_ATTEMPTS_PER_DAY', 3),

    // How long an issued pose prompt stays valid. A selfie must show the pose
    // the server asked for, so a photo taken (or stolen) beforehand doesn't
    // fit; the prompt only lives long enough to take one.
    'challenge_ttl_minutes' => (int) env('VERIFICATION_CHALLENGE_TTL_MINUTES', 15),

    // Selfie upload size cap (KB). Smaller than a profile photo: it's a
    // camera capture, not an album.
    'max_selfie_size_kb' => (int) env('VERIFICATION_MAX_SELFIE_SIZE_KB', 5120),

    // The pose prompts. code => the instruction shown to the person.
    'poses' => [
        'thumbs_up' => 'Give a thumbs up',
        'peace_sign' => 'Show a peace sign',
        'touch_nose' => 'Touch your nose with one finger',
        'wave' => 'Wave at the camera',
    ],

];
