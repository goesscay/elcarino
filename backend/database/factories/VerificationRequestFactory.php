<?php

namespace Database\Factories;

use App\Enums\VerificationMethod;
use App\Enums\VerificationStatus;
use App\Models\User;
use App\Models\VerificationRequest;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<VerificationRequest>
 */
class VerificationRequestFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'method' => VerificationMethod::AiSelfie,
            'status' => VerificationStatus::Processing,
            'pose' => 'thumbs_up',
            'submitted_at' => now(),
        ];
    }

    /** Waiting in the human review queue. */
    public function awaitingReview(): static
    {
        return $this->state(fn () => [
            'method' => VerificationMethod::ManualReview,
            'status' => VerificationStatus::Pending,
            'ai_outcome' => 'inconclusive',
        ]);
    }
}
