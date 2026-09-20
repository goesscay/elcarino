<?php

namespace App\Services\Admin;

use App\Enums\VerificationRejection;
use App\Models\User;
use App\Models\VerificationRequest;
use App\Services\Verification\VerificationService;

/**
 * The human half of verification (open decision #22): a moderator or admin
 * works the queue of requests the matcher couldn't approve on its own. Same
 * shape as ReportModerationService — the decision itself is VerificationService's
 * (so the verified flag, the selfie deletion and the notification can't diverge
 * from the AI path), and the audit-log entry is this class's one call site
 * (docs/06 §8 "every verification decision is audited").
 */
class VerificationModerationService
{
    public function __construct(
        private readonly VerificationService $verification,
        private readonly AuditLogger $audit,
    ) {}

    public function approve(User $reviewer, VerificationRequest $request): void
    {
        $before = ['status' => $request->status->value];

        $this->verification->approveByReviewer($reviewer, $request);

        $this->audit->record($reviewer, 'verification.approved', $request, $before, ['status' => 'approved']);
    }

    public function reject(User $reviewer, VerificationRequest $request, VerificationRejection $reason): void
    {
        $before = ['status' => $request->status->value];

        $this->verification->rejectByReviewer($reviewer, $request, $reason);

        $this->audit->record($reviewer, 'verification.rejected', $request, $before, [
            'status' => 'rejected',
            'reason' => $reason->value,
        ]);
    }
}
