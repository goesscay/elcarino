<?php

namespace App\Enums;

/**
 * reports.category. docs/07-ui-ux-design.md §3.7 "Report — category" lists
 * these exact six as the report form's options, sourced from
 * `GET /safety/report-categories`.
 */
enum ReportCategory: string
{
    case Harassment = 'harassment';
    case FakeProfile = 'fake_profile';
    case Spam = 'spam';
    case InappropriateContent = 'inappropriate_content';
    case Scam = 'scam';
    case Other = 'other';
}
