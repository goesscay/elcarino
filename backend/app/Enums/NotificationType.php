<?php

namespace App\Enums;

/**
 * notifications.type. Phase 1 item 9 only ever writes new_match/new_message/
 * like — subscription/verification/report_status/system belong to features
 * that don't exist yet (Phase 2 subscriptions, verification, report,
 * Filament system announcements). The full enum is declared now anyway, same
 * pattern as MessageType, so no migration is needed once those land.
 */
enum NotificationType: string
{
    case NewMatch = 'new_match';
    case NewMessage = 'new_message';
    case Like = 'like';
    case Subscription = 'subscription';
    case Verification = 'verification';
    case ReportStatus = 'report_status';
    case System = 'system';
}
