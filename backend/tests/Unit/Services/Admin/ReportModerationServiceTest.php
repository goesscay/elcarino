<?php

namespace Tests\Unit\Services\Admin;

use App\Enums\ReportStatus;
use App\Enums\UserRole;
use App\Models\Report;
use App\Models\User;
use App\Services\Admin\ReportModerationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Phase 1 item 11 — the admin/moderator disposition of a report
 * (docs/01-technical-specification.md §19 "Moderation: reports queue").
 */
class ReportModerationServiceTest extends TestCase
{
    use RefreshDatabase;

    private function service(): ReportModerationService
    {
        return app(ReportModerationService::class);
    }

    private function pendingReport(): Report
    {
        $reporter = User::factory()->create();
        $reported = User::factory()->create();

        return Report::query()->create([
            'reporter_id' => $reporter->id,
            'reported_id' => $reported->id,
            'category' => 'harassment',
        ]);
    }

    public function test_action_marks_the_report_reviewed_and_actioned(): void
    {
        $moderator = User::factory()->create(['role' => UserRole::Moderator]);
        $report = $this->pendingReport();

        $this->service()->action($moderator, $report);

        $report->refresh();
        $this->assertSame(ReportStatus::Actioned, $report->status);
        $this->assertSame($moderator->id, $report->reviewed_by);
        $this->assertNotNull($report->reviewed_at);
        $this->assertDatabaseHas('audit_log', [
            'actor_id' => $moderator->id,
            'action' => 'report.actioned',
            'target_type' => $report->getMorphClass(),
            'target_id' => $report->id,
        ]);
    }

    public function test_dismiss_marks_the_report_reviewed_and_dismissed(): void
    {
        $moderator = User::factory()->create(['role' => UserRole::Moderator]);
        $report = $this->pendingReport();

        $this->service()->dismiss($moderator, $report);

        $report->refresh();
        $this->assertSame(ReportStatus::Dismissed, $report->status);
        $this->assertSame($moderator->id, $report->reviewed_by);
        $this->assertDatabaseHas('audit_log', ['actor_id' => $moderator->id, 'action' => 'report.dismissed']);
    }
}
