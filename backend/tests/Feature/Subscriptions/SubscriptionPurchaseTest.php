<?php

namespace Tests\Feature\Subscriptions;

use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SubscriptionPurchaseTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_use_any_subscription_endpoint(): void
    {
        $plan = SubscriptionPlan::factory()->create();

        $this->getJson('/api/v1/subscriptions/plans')->assertUnauthorized();
        $this->getJson('/api/v1/subscriptions/me')->assertUnauthorized();
        $this->postJson('/api/v1/subscriptions', ['plan_id' => $plan->id, 'provider' => 'stripe'])->assertUnauthorized();
        $this->postJson('/api/v1/subscriptions/cancel')->assertUnauthorized();
    }

    public function test_plans_only_lists_active_plans(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $active = SubscriptionPlan::factory()->create(['name' => 'Premium', 'is_active' => true]);
        SubscriptionPlan::factory()->create(['name' => 'Retired plan', 'is_active' => false]);

        $response = $this->getJson('/api/v1/subscriptions/plans')->assertOk();

        $response->assertJsonCount(1, 'plans');
        $response->assertJsonPath('plans.0.id', $active->id);
        $response->assertJsonPath('plans.0.entitlements.unlimited_likes', true);
    }

    public function test_me_returns_null_with_no_subscription(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/subscriptions/me')->assertOk();

        $response->assertJsonPath('subscription', null);
        $response->assertJsonPath('entitlements', []);
    }

    /**
     * PAYMENT_PROVIDER defaults to 'log' (.env.example) — nothing in this
     * test sets it, matching the actual local-dev default this exercises.
     */
    public function test_purchasing_via_the_log_gateway_activates_immediately(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $plan = SubscriptionPlan::factory()->create();

        $response = $this->postJson('/api/v1/subscriptions', [
            'plan_id' => $plan->id,
            'provider' => 'stripe',
        ]);

        $response->assertCreated();
        $response->assertJsonPath('subscription.status', 'active');
        $response->assertJsonPath('subscription.plan.id', $plan->id);
        $this->assertDatabaseHas('subscriptions', ['user_id' => $user->id, 'plan_id' => $plan->id, 'status' => 'active']);
        $this->assertDatabaseHas('payments', ['user_id' => $user->id, 'status' => 'succeeded', 'amount_cents' => $plan->price_cents]);

        $meResponse = $this->getJson('/api/v1/subscriptions/me')->assertOk();
        $meResponse->assertJsonPath('subscription.status', 'active');
        $meResponse->assertJsonPath('entitlements.unlimited_likes', true);
    }

    public function test_purchasing_via_stripe_returns_a_checkout_url_and_creates_no_subscription_yet(): void
    {
        config(['services.payments.provider' => 'stripe', 'services.stripe.secret_key' => 'sk_test_123']);
        Http::fake([
            'https://api.stripe.com/*' => Http::response(['url' => 'https://checkout.stripe.com/c/pay/cs_test_abc']),
        ]);

        Sanctum::actingAs($user = User::factory()->create());
        $plan = SubscriptionPlan::factory()->create();

        $response = $this->postJson('/api/v1/subscriptions', [
            'plan_id' => $plan->id,
            'provider' => 'stripe',
        ]);

        $response->assertStatus(202);
        $response->assertJsonPath('checkout_url', 'https://checkout.stripe.com/c/pay/cs_test_abc');
        $this->assertDatabaseMissing('subscriptions', ['user_id' => $user->id]);
    }

    public function test_a_receipt_is_required_for_native_store_providers(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $plan = SubscriptionPlan::factory()->create();

        $this->postJson('/api/v1/subscriptions', ['plan_id' => $plan->id, 'provider' => 'app_store'])
            ->assertStatus(422)->assertJsonValidationErrors('receipt');
    }

    /**
     * Neither native-store verifier is configured on this machine — a
     * receipt is validated (present) but verification itself fails closed,
     * same as TwilioSmsSender when its credentials are missing.
     */
    public function test_an_unconfigured_app_store_verifier_fails_the_purchase(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $plan = SubscriptionPlan::factory()->create();

        $response = $this->postJson('/api/v1/subscriptions', [
            'plan_id' => $plan->id,
            'provider' => 'app_store',
            'receipt' => 'a-fake-receipt-blob',
        ]);

        $response->assertStatus(422)->assertJsonPath('error.code', 'purchase_failed');
    }

    public function test_a_verified_app_store_receipt_activates_a_subscription(): void
    {
        Http::fake([
            'https://buy.itunes.apple.com/verifyReceipt' => Http::response([
                'status' => 0,
                'latest_receipt_info' => [
                    ['original_transaction_id' => '1000000999', 'expires_date_ms' => (string) (now()->addMonth()->getTimestamp() * 1000)],
                ],
            ]),
        ]);
        config(['services.apple.shared_secret' => 'shared-secret']);

        Sanctum::actingAs($user = User::factory()->create());
        $plan = SubscriptionPlan::factory()->create();

        $response = $this->postJson('/api/v1/subscriptions', [
            'plan_id' => $plan->id,
            'provider' => 'app_store',
            'receipt' => 'a-real-looking-receipt-blob',
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('subscriptions', [
            'user_id' => $user->id,
            'provider' => 'app_store',
            'provider_subscription_id' => '1000000999',
            'status' => 'active',
        ]);
        $this->assertTrue($user->fresh()->isSubscriber());
    }

    public function test_provider_other_is_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $plan = SubscriptionPlan::factory()->create();

        $this->postJson('/api/v1/subscriptions', ['plan_id' => $plan->id, 'provider' => 'other'])
            ->assertStatus(422)->assertJsonValidationErrors('provider');
    }

    public function test_an_inactive_plan_cannot_be_purchased(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $plan = SubscriptionPlan::factory()->create(['is_active' => false]);

        $this->postJson('/api/v1/subscriptions', ['plan_id' => $plan->id, 'provider' => 'stripe'])
            ->assertStatus(422)->assertJsonValidationErrors('plan_id');
    }

    public function test_cancelling_stops_granting_access_immediately(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $plan = SubscriptionPlan::factory()->create();
        $this->postJson('/api/v1/subscriptions', ['plan_id' => $plan->id, 'provider' => 'stripe'])->assertCreated();
        $this->assertTrue($user->fresh()->isSubscriber());

        $response = $this->postJson('/api/v1/subscriptions/cancel')->assertOk();

        $response->assertJsonPath('subscription.status', 'canceled');
        $this->assertFalse($user->fresh()->isSubscriber());
    }

    public function test_cancelling_with_no_active_subscription_is_a_404(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/subscriptions/cancel')
            ->assertStatus(404)->assertJsonPath('error.code', 'no_active_subscription');
    }
}
