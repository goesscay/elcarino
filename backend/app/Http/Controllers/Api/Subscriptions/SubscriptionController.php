<?php

namespace App\Http\Controllers\Api\Subscriptions;

use App\Enums\SubscriptionProvider;
use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Subscriptions\StoreSubscriptionRequest;
use App\Http\Resources\Subscriptions\SubscriptionPlanResource;
use App\Http\Resources\Subscriptions\SubscriptionResource;
use App\Models\SubscriptionPlan;
use App\Services\Payments\ReceiptVerificationException;
use App\Services\Subscriptions\SubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use InvalidArgumentException;

class SubscriptionController extends Controller
{
    use RespondsWithErrorEnvelope;

    public function __construct(private readonly SubscriptionService $subscriptions) {}

    /**
     * GET /api/v1/subscriptions/plans — docs/03 says "public"; kept behind
     * auth like every other route in this group for now, same reasoning as
     * PromptController::index's library endpoint and
     * SafetyController::reportCategories.
     */
    public function plans(): JsonResponse
    {
        $plans = SubscriptionPlan::query()->where('is_active', true)->get();

        return response()->json(['plans' => SubscriptionPlanResource::collection($plans)]);
    }

    /**
     * GET /api/v1/subscriptions/me
     */
    public function me(Request $request): JsonResponse
    {
        $subscription = $request->user()->currentSubscription();

        return response()->json([
            'subscription' => $subscription ? new SubscriptionResource($subscription) : null,
            'entitlements' => $subscription?->plan->entitlements ?? [],
        ]);
    }

    /**
     * POST /api/v1/subscriptions
     */
    public function store(StoreSubscriptionRequest $request): JsonResponse
    {
        $plan = SubscriptionPlan::query()->findOrFail($request->integer('plan_id'));
        $provider = SubscriptionProvider::from($request->string('provider')->toString());

        try {
            $outcome = $this->subscriptions->purchase($request->user(), $plan, $provider, $request->input('receipt'));
        } catch (ReceiptVerificationException|InvalidArgumentException $e) {
            return $this->errorResponse('purchase_failed', $e->getMessage(), 422);
        }

        if ($outcome->subscription) {
            return response()->json(['subscription' => new SubscriptionResource($outcome->subscription)], 201);
        }

        // Stripe redirect path — no subscription exists yet; the webhook
        // creates it once Stripe confirms payment.
        return response()->json(['checkout_url' => $outcome->checkoutUrl], 202);
    }

    /**
     * POST /api/v1/subscriptions/cancel
     */
    public function cancel(Request $request): JsonResponse
    {
        $subscription = $request->user()->currentSubscription();

        if (! $subscription) {
            return $this->errorResponse('no_active_subscription', 'You do not have an active subscription.', 404);
        }

        Gate::authorize('cancel', $subscription);

        $subscription = $this->subscriptions->cancel($request->user(), $subscription);

        return response()->json(['subscription' => new SubscriptionResource($subscription)]);
    }
}
