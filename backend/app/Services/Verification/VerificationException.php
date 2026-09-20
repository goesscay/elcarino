<?php

namespace App\Services\Verification;

use RuntimeException;

/**
 * A business-rule refusal from [VerificationService], carrying the error code
 * and HTTP status the controller turns into docs/03's `{error: {code,
 * message}}` envelope. (Named `$errorCode`, not `$code`: PHP's own Exception
 * already has a non-readonly `$code` — same trap BoostUnavailableException hit.)
 */
class VerificationException extends RuntimeException
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $status = 422,
    ) {
        parent::__construct($message);
    }
}
