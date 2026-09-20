<?php

namespace App\Services\Verification;

/**
 * The default matcher, until a provider is chosen [TBD-21]: it never approves
 * anything and never rejects anything, it just says "I can't tell", so every
 * request lands in the human review queue (open decision #22). Failing toward
 * a person is the safe default for a trust badge — the opposite mistake, a
 * matcher that approves by default, would hand out verified badges to anyone.
 */
class UnconfiguredFaceMatcher implements FaceMatcher
{
    public function compare(string $selfie, array $references): FaceMatchResult
    {
        return new FaceMatchResult(FaceMatchOutcome::Inconclusive);
    }
}
