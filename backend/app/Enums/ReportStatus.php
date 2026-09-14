<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

/**
 * reports.status. Only `pending` (the default) is ever written by the
 * report-creation feature (Phase 1 item 10) — reviewing/actioned/dismissed
 * are set by the admin reports queue (Phase 1 item 11), via
 * App\Services\Admin\ReportModerationService.
 */
enum ReportStatus: string implements HasColor, HasLabel
{
    case Pending = 'pending';
    case Reviewing = 'reviewing';
    case Actioned = 'actioned';
    case Dismissed = 'dismissed';

    public function getLabel(): string
    {
        return match ($this) {
            self::Pending => 'Pending',
            self::Reviewing => 'Reviewing',
            self::Actioned => 'Actioned',
            self::Dismissed => 'Dismissed',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Pending => 'warning',
            self::Reviewing => 'info',
            self::Actioned => 'danger',
            self::Dismissed => 'gray',
        };
    }
}
