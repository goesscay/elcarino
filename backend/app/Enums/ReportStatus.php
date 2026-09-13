<?php

namespace App\Enums;

/**
 * reports.status. Only `pending` (the default) is ever written by this
 * feature — reviewing/actioned/dismissed are set by the admin reports queue
 * (Phase 1 item 11), which doesn't exist yet.
 */
enum ReportStatus: string
{
    case Pending = 'pending';
    case Reviewing = 'reviewing';
    case Actioned = 'actioned';
    case Dismissed = 'dismissed';
}
