<?php

namespace App\Providers;

use App\Models\User;
use App\Services\Auth\OAuth\AppleTokenVerifier;
use App\Services\Auth\OAuth\GoogleTokenVerifier;
use App\Services\Auth\OtpService;
use App\Services\Gifs\GifProvider;
use App\Services\Gifs\GiphyGifProvider;
use App\Services\Gifs\LogGifProvider;
use App\Services\Payments\AppStoreReceiptVerifier;
use App\Services\Payments\LogPaymentGateway;
use App\Services\Payments\PaymentGateway;
use App\Services\Payments\PlayStoreReceiptVerifier;
use App\Services\Payments\StripePaymentGateway;
use App\Services\Push\FcmPushSender;
use App\Services\Push\LogPushSender;
use App\Services\Push\PushSender;
use App\Services\Sms\LogSmsSender;
use App\Services\Sms\SmsSender;
use App\Services\Sms\TwilioSmsSender;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(SmsSender::class, function () {
            return match (config('services.sms.provider')) {
                'twilio' => new TwilioSmsSender(
                    config('services.sms.twilio.sid'),
                    config('services.sms.twilio.token'),
                    config('services.sms.twilio.from'),
                ),
                default => new LogSmsSender,
            };
        });

        $this->app->bind(PushSender::class, function () {
            return match (config('services.push.provider')) {
                'fcm' => new FcmPushSender(
                    config('services.push.fcm.project_id'),
                    config('services.push.fcm.service_account_email'),
                    config('services.push.fcm.service_account_private_key'),
                ),
                default => new LogPushSender,
            };
        });

        $this->app->bind(GoogleTokenVerifier::class, fn () => new GoogleTokenVerifier(config('services.google.client_id')));
        $this->app->bind(AppleTokenVerifier::class, fn () => new AppleTokenVerifier(config('services.apple.client_id')));

        $this->app->bind(OtpService::class, fn ($app) => new OtpService(
            $app->make(SmsSender::class),
            config('otp.ttl_seconds'),
            config('otp.max_attempts'),
        ));

        // Phase 2 item 1 — provider-agnostic, same switch-on-a-config-value
        // pattern as SmsSender/PushSender above. Native store billing
        // (app_store/play_store) isn't switched here at all — see
        // ReceiptVerifier's own doc comment for why that's a separate path.
        $this->app->bind(PaymentGateway::class, function () {
            return match (config('services.payments.provider')) {
                'stripe' => new StripePaymentGateway(
                    config('services.stripe.secret_key'),
                    config('services.stripe.success_url'),
                    config('services.stripe.cancel_url'),
                ),
                default => new LogPaymentGateway,
            };
        });

        $this->app->bind(AppStoreReceiptVerifier::class, fn () => new AppStoreReceiptVerifier(
            config('services.apple.shared_secret'),
        ));

        $this->app->bind(PlayStoreReceiptVerifier::class, fn () => new PlayStoreReceiptVerifier(
            config('services.play.service_account_email'),
            config('services.play.service_account_private_key'),
        ));

        // Phase 3 item 2 — same switch-on-a-config-value pattern as
        // SmsSender/PushSender/PaymentGateway above.
        $this->app->bind(GifProvider::class, function () {
            return match (config('services.gifs.provider')) {
                'giphy' => new GiphyGifProvider(
                    config('services.gifs.giphy.api_key'),
                    config('services.gifs.giphy.rating'),
                ),
                default => new LogGifProvider,
            };
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureRateLimiting();
        $this->configurePasswordResetUrl();
        $this->configureAdminGates();
    }

    /**
     * docs/06-security-architecture.md §3.3: "Moderators: reports queue +
     * verification review + user suspend only. Cannot delete users..."
     * Defined as Gates (not a User Policy) because these are coarse,
     * record-independent admin-panel abilities, not per-resource
     * ownership checks. Re-checked inside the Filament action closures
     * themselves (see UsersTable) — hiding the button is defence in depth,
     * never the actual control, same discipline as every API policy.
     */
    private function configureAdminGates(): void
    {
        Gate::define('banUsers', fn (User $user) => $user->isAdmin());
        Gate::define('deleteUsers', fn (User $user) => $user->isAdmin());

        // Who liked me (docs/07 §3.4) is a subscriber feature, checked here
        // so the rule has one home; LikesController answers a denial with a
        // locked, identity-free payload rather than a 403 (the tab still
        // shows the count and the upgrade prompt).
        Gate::define('view-who-liked-me', fn (User $user) => $user->isSubscriber());
    }

    /**
     * This is an API — there's no Blade `password.reset` route for Laravel's
     * default notification to link to. Point it at the client's own
     * reset-password screen instead (a hosted page or a mobile deep link;
     * FRONTEND_RESET_PASSWORD_URL is a placeholder until the onboarding/
     * settings feature has a real one — see docs/05-open-decisions.md).
     */
    private function configurePasswordResetUrl(): void
    {
        ResetPassword::createUrlUsing(function ($notifiable, string $token) {
            // TODO: point this at the real client reset-password surface once
            // one exists, via a proper env-backed config key.
            $base = config('app.url').'/reset-password';

            return $base.'?token='.$token.'&email='.urlencode($notifiable->getEmailForPasswordReset());
        });
    }

    /**
     * Rate limits per security doc §7. Bounds abuse surfaces (credential
     * stuffing, OTP brute force / SMS-bombing) without needing Redis locally.
     */
    private function configureRateLimiting(): void
    {
        RateLimiter::for('login', fn ($request) => [
            Limit::perMinute(5)->by($request->ip()),
            Limit::perHour(10)->by((string) $request->input('email', $request->input('phone'))),
        ]);

        RateLimiter::for('otp-request', fn ($request) => [
            Limit::perMinute(1)->by($request->input('phone')),
            Limit::perHour(5)->by($request->input('phone')),
            Limit::perHour(20)->by($request->ip()),
        ]);

        RateLimiter::for('otp-verify', fn ($request) => Limit::perMinute(10)->by($request->input('phone')));

        RateLimiter::for('auth-write', fn ($request) => Limit::perMinute(10)->by($request->ip()));

        // docs/06 §4: "Location updates are rate-limited (max 1 stored
        // update / 5 min / user)."
        RateLimiter::for('location-update', fn ($request) => Limit::perMinutes(5, 1)->by($request->user()->id));

        // docs/06 §7 rate limit table: "discovery/feed | 60 / hour / user".
        RateLimiter::for('discovery-feed', fn ($request) => Limit::perHour(60)->by($request->user()->id));

        // Explore runs the same eligibility scan as the feed on every call, so
        // it is limited in the same spirit: room for browsing a few categories,
        // not for enumerating everyone (docs/06 section 7).
        RateLimiter::for('explore', fn ($request) => Limit::perHour(120)->by($request->user()->id));

        // Likes tab lists: same scraping concern as the feed, but a person
        // pulls to refresh two tabs, so a separate, roomier bucket.
        RateLimiter::for('likes-list', fn ($request) => Limit::perHour(120)->by($request->user()->id));

        // docs/06 §7: "swipes | 100 / hour / user (free), higher for
        // subscribers; hard ceiling regardless of tier." isSubscriber() is
        // stubbed to false until Phase 2, so the 300/hour branch is unreached
        // for now but ready — never hardcode the higher tier as the default.
        RateLimiter::for('swipes', fn ($request) => Limit::perHour($request->user()->isSubscriber() ? 300 : 100)
            ->by($request->user()->id));

        // docs/06 §7 rate limit table: "chat/messages send | 30 / min /
        // conversation, 300 / hour / user." Route middleware runs before
        // SubstituteBindings resolves {conversation} to a model, so
        // route('conversation') is still the raw id string here — that's
        // fine, it's just as good a distinguishing key as the resolved
        // model's id would be (confirmed by testing this, not assumed).
        RateLimiter::for('chat-messages', fn ($request) => [
            Limit::perMinute(30)->by('conversation:'.$request->route('conversation')),
            Limit::perHour(300)->by($request->user()->id),
        ]);

        // docs/06 §7 rate limit table: "safety/report | 20 / day / user (a
        // user reporting dozens of people per hour is itself a signal)."
        RateLimiter::for('safety-report', fn ($request) => Limit::perDay(20)->by($request->user()->id));

        // Not in docs/06 §7's table (predates Phase 3) — a provisional cap
        // in the same spirit as media.php's upload limits: a GIF search is
        // cheap for us but still a proxied third-party API call worth
        // bounding, especially per-keystroke live search from the mobile
        // composer.
        RateLimiter::for('gif-search', fn ($request) => Limit::perMinute(60)->by($request->user()->id));

        // Not in docs/06 §7's table (predates Phase 3) — a provisional cap,
        // same spirit as chat-messages: bounds call-spamming a match
        // without meaningfully limiting legitimate use (nobody places more
        // than a handful of calls a minute).
        RateLimiter::for('call-token', fn ($request) => Limit::perMinute(10)->by($request->user()->id));
    }
}
