<?php

namespace App\Services\Verification;

/**
 * The AI half of verification: does this selfie show the same person as the
 * profile photos? Provider-agnostic on purpose (same shape as SmsSender /
 * PushSender / PaymentGateway) because the provider is an open decision
 * [TBD-21]. Implementations receive raw JPEG bytes and return a result; they
 * must not log or persist them (docs/06 §5: verification photos are
 * "Critical" data, excluded from every log sink) and should send the provider
 * the minimum it needs (Phase 4 gate: "AI provider receives only the minimum
 * necessary data").
 */
interface FaceMatcher
{
    /**
     * @param  string  $selfie  JPEG bytes of the just-taken selfie
     * @param  list<string>  $references  JPEG bytes of the person's profile photos
     */
    public function compare(string $selfie, array $references): FaceMatchResult;
}
