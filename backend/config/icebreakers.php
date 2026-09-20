<?php

/*
 * AI icebreakers (Phase 4, open decision #25): a few tappable opening lines for
 * a brand new conversation, drawn from what the two people have in common.
 */
return [

    // Who writes the suggestions.
    //
    // `template` (the default) builds them from fixed patterns and the shared
    // interests / prompt answers. It needs no key and **sends nothing to any
    // third party**, so it is always safe to run.
    //
    // `openai` asks the OpenAI API (the spec's AI provider, docs/01 §2) for
    // more natural lines. That sends the *other* person's prompt answers and bio
    // to OpenAI, which is a data-sharing decision the client and legal need to
    // sign off (and the privacy policy must disclose) before it is switched on
    // [TBD-25]. With no key set it falls back to `template` rather than failing.
    'provider' => env('ICEBREAKER_PROVIDER', 'template'),

    'openai' => [
        'api_key' => env('OPENAI_API_KEY'),
        // Provisional: a small, cheap model is plenty for one-line openers.
        'model' => env('ICEBREAKER_OPENAI_MODEL', 'gpt-4o-mini'),
        'timeout_seconds' => (int) env('ICEBREAKER_OPENAI_TIMEOUT', 8),
    ],

    // How many suggestions to show. [TBD-25] provisional.
    'count' => (int) env('ICEBREAKER_COUNT', 3),

    // How long a set of suggestions is kept for one person in one conversation,
    // so re-opening the chat doesn't re-run (and re-pay for) the generator.
    'cache_ttl_hours' => (int) env('ICEBREAKER_CACHE_TTL_HOURS', 24),

    // What a suggestion may look like. Applied to *everything* a generator
    // returns, so a model that was talked into something odd by a profile
    // written to manipulate it can't put it on someone's screen.
    'min_length' => 10,
    'max_length' => 160,

    // How much of the other person's text a generator ever sees.
    'max_bio_chars' => 300,
    'max_prompts' => 3,
    'max_shared_interests' => 5,

];
