<?php

namespace App\Http\Resources\Verification;

use App\Enums\VerificationRejection;
use App\Enums\VerificationStatus;
use App\Models\VerificationRequest;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * What the person may see of their own verification request: where it stands
 * and, if it was rejected, person-safe copy. Never the matcher's score or
 * outcome, and never the reviewer — those are the reviewer's, and showing
 * "your score was 61" would just teach people to game the threshold.
 *
 * @mixin VerificationRequest
 */
class VerificationRequestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $result = $this->result;
        $reason = $result?->reason ? VerificationRejection::tryFrom($result->reason) : null;

        return [
            'id' => $this->id,
            // Both "processing" and "pending" read to the person as "we're
            // checking"; the distinction is ours (AI vs a human queue).
            'status' => $this->status === VerificationStatus::Rejected || $this->status === VerificationStatus::Approved
                ? $this->status->value
                : 'in_review',
            'submitted_at' => $this->submitted_at->toIso8601String(),
            'decided_at' => $result?->decided_at->toIso8601String(),
            'reason' => $reason?->value,
            'reason_message' => $reason?->userMessage(),
        ];
    }
}
