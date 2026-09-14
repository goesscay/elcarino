<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

/**
 * reports.category. docs/07-ui-ux-design.md §3.7 "Report — category" lists
 * these exact six as the report form's options, sourced from
 * `GET /safety/report-categories`.
 */
enum ReportCategory: string implements HasLabel
{
    case Harassment = 'harassment';
    case FakeProfile = 'fake_profile';
    case Spam = 'spam';
    case InappropriateContent = 'inappropriate_content';
    case Scam = 'scam';
    case Other = 'other';

    public function getLabel(): string
    {
        return match ($this) {
            self::Harassment => 'Harassment',
            self::FakeProfile => 'Fake profile',
            self::Spam => 'Spam',
            self::InappropriateContent => 'Inappropriate content',
            self::Scam => 'Scam',
            self::Other => 'Other',
        };
    }
}
