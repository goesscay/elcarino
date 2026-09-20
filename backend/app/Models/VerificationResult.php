<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * The decision on a [VerificationRequest] (docs/02): who made it (`ai` or an
 * `admin`), how confident the AI was, which reviewer, and — for a rejection —
 * why. docs/06 §9 / Phase 4 gate: "verification decisions are auditable".
 */
#[Fillable(['verification_request_id', 'decided_by', 'confidence_score', 'reviewer_id', 'reason', 'decided_at'])]
class VerificationResult extends Model
{
    protected function casts(): array
    {
        return [
            'confidence_score' => 'float',
            'decided_at' => 'datetime',
        ];
    }

    public function request(): BelongsTo
    {
        return $this->belongsTo(VerificationRequest::class, 'verification_request_id');
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewer_id');
    }
}
