<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'google' => [
        // ?: normalizes an unset/blank .env value to null — GoogleTokenVerifier
        // treats null as "don't check the audience claim" (local dev without a
        // configured client id), an empty string would otherwise never match.
        'client_id' => env('GOOGLE_CLIENT_ID') ?: null,
    ],

    'apple' => [
        'client_id' => env('APPLE_CLIENT_ID') ?: null,
        // App Store receipt verification (Phase 2 item 1) — a different
        // secret than the Sign In With Apple client id above, kept under
        // the same 'apple' key since both are Apple-issued credentials.
        'shared_secret' => env('APPLE_SHARED_SECRET') ?: null,
    ],

    'play' => [
        // Google Play Developer API service account (Phase 2 item 1) — a
        // *different* Google credential than 'google.client_id' above
        // (that one verifies a Sign-In ID token; this one calls the
        // Play Developer API), kept as its own key rather than overloading
        // 'google'.
        'service_account_email' => env('PLAY_SERVICE_ACCOUNT_EMAIL') ?: null,
        'service_account_private_key' => env('PLAY_SERVICE_ACCOUNT_PRIVATE_KEY') ?: null,
    ],

    'sms' => [
        'provider' => env('SMS_PROVIDER', 'log'),
        'twilio' => [
            'sid' => env('TWILIO_SID'),
            'token' => env('TWILIO_TOKEN'),
            'from' => env('TWILIO_FROM'),
        ],
    ],

    'push' => [
        // Firebase Cloud Messaging is confirmed, not a TBD (spec §18) — this
        // provider switch exists only so local dev doesn't need a real
        // Firebase project configured, same as SMS_PROVIDER above.
        'provider' => env('PUSH_PROVIDER', 'log'),
        'fcm' => [
            'project_id' => env('FCM_PROJECT_ID'),
            'service_account_email' => env('FCM_SERVICE_ACCOUNT_EMAIL'),
            'service_account_private_key' => env('FCM_SERVICE_ACCOUNT_PRIVATE_KEY'),
        ],
    ],

    'payments' => [
        // Open decision #27 (payment gateway) — 'log' activates a purchase
        // immediately without any real charge, same role as SMS_PROVIDER/
        // PUSH_PROVIDER=log; 'stripe' is this feature's chosen working
        // default (docs/04 item 1), not yet exercised against a real
        // account. Native store billing (app_store/play_store) is a
        // separate, always-available code path — see 'apple'/'play' above
        // and App\Services\Payments\ReceiptVerifier.
        'provider' => env('PAYMENT_PROVIDER', 'log'),
    ],

    'stripe' => [
        'secret_key' => env('STRIPE_SECRET_KEY') ?: null,
        'webhook_secret' => env('STRIPE_WEBHOOK_SECRET') ?: null,
        // Where Stripe Checkout redirects after payment — no mobile
        // deep-link handler exists yet for either outcome (flagged in
        // StripePaymentGateway's doc comment), so these default to plain
        // backend URLs rather than an app:// scheme that goes nowhere.
        'success_url' => env('STRIPE_SUCCESS_URL') ?: null,
        'cancel_url' => env('STRIPE_CANCEL_URL') ?: null,
    ],

    'gifs' => [
        // Open decision #17 (GIFs) — 'log' is the safe default (no outbound
        // call at all, same role as SMS_PROVIDER/PUSH_PROVIDER/
        // PAYMENT_PROVIDER=log) and what tests/CI always run against.
        // 'giphy' is this feature's chosen provider — the de facto standard
        // for exactly this use case (it's what Tinder itself uses). Still
        // never the `.env` default, deliberately, so automated tests stay
        // network-free.
        'provider' => env('GIF_PROVIDER', 'log'),
        'giphy' => [
            // `?:`, not env()'s own default arg — GIPHY_API_KEY is present
            // but blank in .env.example/.env (documents the variable exists
            // without implying a real key is required), and env()'s second
            // argument only ever applies when the key is fully absent, same
            // normalization already used for GOOGLE_CLIENT_ID/APPLE_CLIENT_ID
            // above. Falls back to Giphy's own documented public beta key —
            // checked live while building this feature and it's currently
            // dead (every request returns `{"meta":{"status":403,"msg":
            // "BANNED"}}`, not a real result), so this fallback is really
            // just "fail the same documented way as an unconfigured key"
            // rather than a working zero-setup default the way it was
            // presumably meant to be. Set GIPHY_API_KEY to a real
            // (registered) key before relying on 'giphy' at all — unlike
            // TwilioSmsSender/StripePaymentGateway, this provider hasn't
            // been exercised against so much as a real response, only
            // against Http::fake() in GiphyGifProviderTest.
            'api_key' => env('GIPHY_API_KEY') ?: 'dc6zaTOxFJmzC',
            // Giphy's own content-rating scale. A dating app showing
            // third-party search results to adults — "pg-13" is a
            // provisional, revisable default, same spirit as media.php's
            // upload caps, not a business decision.
            'rating' => env('GIPHY_RATING') ?: 'pg-13',
        ],
    ],

];
