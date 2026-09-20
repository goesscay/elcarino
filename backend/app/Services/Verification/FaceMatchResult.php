<?php

namespace App\Services\Verification;

/**
 * A [FaceMatcher]'s answer: the outcome and, when it has one, a 0-100
 * confidence score.
 */
final readonly class FaceMatchResult
{
    public function __construct(
        public FaceMatchOutcome $outcome,
        public ?float $score = null,
    ) {}
}
