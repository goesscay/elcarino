<?php

namespace App\Http\Controllers\Webhooks;

use App\Http\Controllers\Controller;
use App\Services\Payments\StripeWebhookSignatureVerifier;
use App\Services\Subscriptions\SubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * `POST /api/webhooks/stripe` — deliberately outside `/api/v1` and outside
 * `auth:sanctum`, same reasoning as `/api/broadcasting/auth`
 * (bootstrap/app.php): Stripe cannot hold a Sanctum bearer token, so the
 * `Stripe-Signature` header (StripeWebhookSignatureVerifier) is the entire
 * authentication for this endpoint, not a defence-in-depth extra.
 */
class StripeWebhookController extends Controller
{
    public function __construct(
        private readonly StripeWebhookSignatureVerifier $verifier,
        private readonly SubscriptionService $subscriptions,
    ) {}

    public function handle(Request $request): JsonResponse
    {
        $webhookSecret = config('services.stripe.webhook_secret');

        if (! $webhookSecret) {
            // Not configured locally — accept nothing rather than trust an
            // unverifiable payload. Real delivery only ever reaches this
            // once STRIPE_WEBHOOK_SECRET is set.
            return response()->json(['error' => 'Stripe webhooks are not configured.'], 503);
        }

        $verified = $this->verifier->verify(
            $request->getContent(),
            $request->header('Stripe-Signature'),
            $webhookSecret,
        );

        if (! $verified) {
            Log::warning('Stripe webhook signature verification failed.');

            return response()->json(['error' => 'Invalid signature.'], 400);
        }

        $event = $request->json()->all();
        $this->subscriptions->handleStripeEvent($event);

        return response()->json(['received' => true]);
    }
}
