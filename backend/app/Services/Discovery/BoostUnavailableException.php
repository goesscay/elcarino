<?php

namespace App\Services\Discovery;

use RuntimeException;

/**
 * One exception, not per-cause classes, since the controller only ever
 * needs to relay `$errorCode`/`$httpStatus`/the message — no branching
 * logic of its own depends on which cause it was.
 *
 * Named `$errorCode`, not `$code`: PHP's built-in `Exception` already
 * declares a non-readonly `$code` property, and promoting a constructor
 * param of the same name as `readonly` fatals at class-load time
 * ("Cannot redeclare non-readonly property ... as readonly") — caught live
 * via tinker, not by a test that happened not to touch this path.
 */
class BoostUnavailableException extends RuntimeException
{
    public function __construct(public readonly string $errorCode, string $message, public readonly int $httpStatus)
    {
        parent::__construct($message);
    }

    public static function noEntitlement(): self
    {
        return new self(
            'upgrade_required',
            'Profile boost is a Premium feature.',
            403,
        );
    }

    public static function alreadyActive(): self
    {
        return new self(
            'boost_already_active',
            'You already have an active boost.',
            409,
        );
    }

    public static function limitReached(int $limit): self
    {
        return new self(
            'boost_limit_reached',
            "You've used all {$limit} of your boosts for this month.",
            403,
        );
    }
}
