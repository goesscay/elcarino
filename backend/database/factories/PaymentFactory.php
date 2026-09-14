<?php

namespace Database\Factories;

use App\Enums\PaymentStatus;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Payment>
 */
class PaymentFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'subscription_id' => null,
            'amount_cents' => 999,
            'currency' => 'USD',
            'status' => PaymentStatus::Succeeded,
            'provider_reference' => 'pi_'.fake()->uuid(),
        ];
    }
}
