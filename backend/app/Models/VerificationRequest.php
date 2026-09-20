<?php

namespace App\Models;

use App\Enums\VerificationMethod;
use App\Enums\VerificationStatus;
use Database\Factories\VerificationRequestFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * One attempt to get the verified badge (docs/01 §15, docs/02 "Verification").
 * `selfie_path` holds the *encrypted* upload and is nulled the moment a
 * decision is made (VerificationService) — the row is the audit trail, the
 * biometric-ish photo is not kept.
 */
#[Fillable(['user_id', 'method', 'status', 'pose', 'selfie_path', 'ai_outcome', 'ai_score', 'submitted_at'])]
class VerificationRequest extends Model
{
    /** @use HasFactory<VerificationRequestFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'method' => VerificationMethod::class,
            'status' => VerificationStatus::class,
            'ai_score' => 'float',
            'submitted_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function result(): HasOne
    {
        return $this->hasOne(VerificationResult::class);
    }
}
