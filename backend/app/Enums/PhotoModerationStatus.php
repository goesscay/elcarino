<?php

namespace App\Enums;

/**
 * profile_photos.moderation_status. A `pending` photo is visible only to its
 * owner until `approved` — docs/06-security-architecture.md §6.
 */
enum PhotoModerationStatus: string
{
    case Pending = 'pending';
    case Approved = 'approved';
    case Rejected = 'rejected';
}
