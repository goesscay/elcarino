<?php

namespace Tests\Feature\Subscriptions;

use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * `/api/webhooks/stripe` has no Sanctum auth at all (Stripe can't hold a
 * bearer token) — the `Stripe-Signature` header is the entire
 * authentication, so this suite tests that boundary directly via raw
 * `postJson`-style calls with a hand-computed signature, not `Sanctum::actingAs`.
 */
class StripeWebhookTest extends TestCase
{
    use RefreshDatabase;

    private const SECRET = 'whsec_test_secret';

    /**
     * Not `withHeaders()->call(...)` — `call()` is the low-level helper and
     * only reads its own `$server` argument, not `$this->defaultHeaders`
     * (that's `post()`/`json()`'s job, and neither lets this test control
     * the raw body bytes the signature is computed over). Uses the same
     * `transformHeadersToServerVars()` those higher-level helpers use
     * internally, so the header ends up in the SERVER array the exact same
     * way a real request's would.
     */
    private function postWebhook(array $event): TestResponse
    {
        $payload = json_encode($event);
        $timestamp = time();
        $signature = hash_hmac('sha256', "{$timestamp}.{$payload}", self::SECRET);

        $server = $this->transformHeadersToServerVars([
            'Stripe-Signature' => "t={$timestamp},v1={$signature}",
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
        ]);

        return $this->call('POST', '/api/webhooks/stripe', [], [], [], $server, $payload);
    }

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.stripe.webhook_secret' => self::SECRET]);
    }

    public function test_it_rejects_a_request_with_no_signature(): void
    {
        $this->postJson('/api/webhooks/stripe', ['type' => 'checkout.session.completed'])
            ->assertStatus(400);
    }

    public function test_it_rejects_a_request_when_no_webhook_secret_is_configured(): void
    {
        config(['services.stripe.webhook_secret' => null]);

        $this->postWebhook(['type' => 'checkout.session.completed'])->assertStatus(503);
    }

    public function test_checkout_session_completed_activates_a_subscription(): void
    {
        $user = User::factory()->create();
        $plan = SubscriptionPlan::factory()->create();

        $response = $this->postWebhook([
            'type' => 'checkout.session.completed',
            'data' => ['object' => [
                'subscription' => 'sub_abc123',
                'metadata' => ['user_id' => (string) $user->id, 'plan_id' => (string) $plan->id],
            ]],
        ]);

        $response->assertOk()->assertJsonPath('received', true);
        $this->assertDatabaseHas('subscriptions', [
            'user_id' => $user->id,
            'plan_id' => $plan->id,
            'status' => 'active',
            'provider_subscription_id' => 'sub_abc123',
        ]);
        $this->assertTrue($user->fresh()->isSubscriber());
    }

    public function test_replaying_the_same_event_does_not_create_a_second_subscription(): void
    {
        $user = User::factory()->create();
        $plan = SubscriptionPlan::factory()->create();
        $event = [
            'type' => 'checkout.session.completed',
            'data' => ['object' => [
                'subscription' => 'sub_abc123',
                'metadata' => ['user_id' => (string) $user->id, 'plan_id' => (string) $plan->id],
            ]],
        ];

        $this->postWebhook($event)->assertOk();
        $this->postWebhook($event)->assertOk();

        $this->assertSame(1, Subscription::query()->where('provider_subscription_id', 'sub_abc123')->count());
    }

    public function test_subscription_deleted_cancels_it(): void
    {
        $user = User::factory()->create();
        $plan = SubscriptionPlan::factory()->create();
        $this->postWebhook([
            'type' => 'checkout.session.completed',
            'data' => ['object' => ['subscription' => 'sub_xyz', 'metadata' => ['user_id' => (string) $user->id, 'plan_id' => (string) $plan->id]]],
        ])->assertOk();
        $this->assertTrue($user->fresh()->isSubscriber());

        $this->postWebhook([
            'type' => 'customer.subscription.deleted',
            'data' => ['object' => ['id' => 'sub_xyz']],
        ])->assertOk();

        $this->assertFalse($user->fresh()->isSubscriber());
        $this->assertDatabaseHas('subscriptions', ['provider_subscription_id' => 'sub_xyz', 'status' => 'canceled']);
    }

    public function test_payment_failed_marks_the_subscription_past_due(): void
    {
        $user = User::factory()->create();
        $plan = SubscriptionPlan::factory()->create();
        $this->postWebhook([
            'type' => 'checkout.session.completed',
            'data' => ['object' => ['subscription' => 'sub_pd', 'metadata' => ['user_id' => (string) $user->id, 'plan_id' => (string) $plan->id]]],
        ])->assertOk();

        $this->postWebhook([
            'type' => 'invoice.payment_failed',
            'data' => ['object' => ['subscription' => 'sub_pd']],
        ])->assertOk();

        $this->assertDatabaseHas('subscriptions', ['provider_subscription_id' => 'sub_pd', 'status' => 'past_due']);
        // past_due is not active — no grace period implemented (flagged in
        // SubscriptionService's own doc comment).
        $this->assertFalse($user->fresh()->isSubscriber());
    }

    public function test_an_unrecognised_event_type_is_ignored_without_error(): void
    {
        $this->postWebhook(['type' => 'customer.created', 'data' => ['object' => []]])
            ->assertOk()->assertJsonPath('received', true);
    }
}
