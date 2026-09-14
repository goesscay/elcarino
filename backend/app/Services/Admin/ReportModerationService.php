<?php

namespace App\Services\Admin;

use App\Enums\ReportStatus;
use App\Models\Report;
use App\Models\User;

/**
 * docs/01-technical-specification.md §19 "Moderation: reports queue" —
 * the admin/moderator disposition of a report. Kept symmetrical with
 * AccountModerationService (one transition helper, one audit-log call site).
 */
class ReportModerationService
{
    public function __construct(private readonly AuditLogger $audit) {}

    public function action(User $actor, Report $report): void
    {
        $this->transition($actor, $report, ReportStatus::Actioned);
    }

    public function dismiss(User $actor, Report $report): void
    {
        $this->transition($actor, $report, ReportStatus::Dismissed);
    }

    private function transition(User $actor, Report $report, ReportStatus $to): void
    {
        $before = ['status' => $report->status->value];
        $report->forceFill([
            'status' => $to,
            'reviewed_by' => $actor->id,
            'reviewed_at' => now(),
        ])->save();

        $this->audit->record($actor, "report.{$to->value}", $report, $before, ['status' => $to->value]);
    }
}
