<?php

namespace App\Services\Verification;

/**
 * A stand-in matcher for local development: reports whatever
 * `config('verification.fake')` says, without looking at the pictures. It exists
 * so the whole flow (approve, no face, needs a human) can be driven end to end
 * on a laptop with no provider account — same role as LogSmsSender.
 *
 * Because "always matched" would hand out badges to anyone if it leaked into
 * production, AppServiceProvider refuses to build it outside local/testing.
 */
class FakeFaceMatcher implements FaceMatcher
{
    public function __construct(
        private readonly FaceMatchOutcome $outcome,
        private readonly float $score,
    ) {}

    public function compare(string $selfie, array $references): FaceMatchResult
    {
        return new FaceMatchResult(
            $this->outcome,
            $this->outcome === FaceMatchOutcome::Matched ? $this->score : null,
        );
    }
}
