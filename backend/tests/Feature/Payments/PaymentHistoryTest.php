<?php

namespace Tests\Feature\Payments;

use App\Models\Payment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PaymentHistoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_view_payment_history(): void
    {
        $this->getJson('/api/v1/payments/history')->assertUnauthorized();
    }

    public function test_it_returns_only_the_callers_own_payments_newest_first(): void
    {
        Sanctum::actingAs($user = User::factory()->create());
        $older = Payment::factory()->for($user)->create(['created_at' => now()->subDay()]);
        $newer = Payment::factory()->for($user)->create(['created_at' => now()]);
        Payment::factory()->create(); // another user's payment

        $response = $this->getJson('/api/v1/payments/history')->assertOk();

        $response->assertJsonCount(2, 'payments');
        $response->assertJsonPath('payments.0.id', $newer->id);
        $response->assertJsonPath('payments.1.id', $older->id);
    }
}
