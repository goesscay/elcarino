<?php

namespace App\Providers;

use App\Services\Auth\OAuth\AppleTokenVerifier;
use App\Services\Auth\OAuth\GoogleTokenVerifier;
use App\Services\Auth\OtpService;
use App\Services\Push\FcmPushSender;
use App\Services\Push\LogPushSender;
use App\Services\Push\PushSender;
use App\Services\Sms\LogSmsSender;
use App\Services\Sms\SmsSender;
use App\Services\Sms\TwilioSmsSender;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Cache\RateLimiting\Limit;
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
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureRateLimiting();
        $this->configurePasswordResetUrl();
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
    }
}
