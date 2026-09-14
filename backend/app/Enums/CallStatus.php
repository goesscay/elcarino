<?php

namespace App\Enums;

/**
 * calls.status. See the `create_calls_table` migration's doc comment for
 * what each value means — `Failed` is declared but never written this pass
 * (no client-reported ICE-failure endpoint exists yet).
 */
enum CallStatus: string
{
    case Ringing = 'ringing';
    case Active = 'active';
    case Ended = 'ended';
    case Missed = 'missed';
    case Declined = 'declined';
    case Failed = 'failed';
}
