<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

/**
 * verification_requests.method (docs/02, open decisions #21-23). A request
 * starts as `ai_selfie`; when the matcher can't approve it confidently it
 * becomes `manual_review` (#22, the human fallback). `id_document` (#23) is in
 * the schema enum but not built — "not assumed in scope unless required for a
 * specific launch market's compliance".
 */
enum VerificationMethod: string implements HasLabel
{
    case AiSelfie = 'ai_selfie';
    case ManualReview = 'manual_review';
    case IdDocument = 'id_document';

    public function getLabel(): string
    {
        return match ($this) {
            self::AiSelfie => 'AI selfie match',
            self::ManualReview => 'Manual review',
            self::IdDocument => 'ID document',
        };
    }
}
