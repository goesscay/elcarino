<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\VerificationRequest;
use App\Services\Admin\AuditLogger;
use App\Services\Verification\VerificationPhotoStore;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Streams a pending request's selfie to the reviewer looking at it in the admin
 * panel. The selfie is "Critical" data (docs/06 §5: encrypted at rest, **access
 * logged**, never cached), so this is the only door to it and every view is an
 * audit-log entry. Admin/moderator session only — the same people who can open
 * the panel; a mobile bearer token has no route here.
 */
class VerificationSelfieController extends Controller
{
    public function __construct(
        private readonly VerificationPhotoStore $photos,
        private readonly AuditLogger $audit,
    ) {}

    public function show(Request $request, VerificationRequest $verificationRequest): Response
    {
        $viewer = $request->user();
        abort_unless($viewer && ($viewer->isAdmin() || $viewer->isModerator()), 403);

        $bytes = $verificationRequest->selfie_path ? $this->photos->get($verificationRequest->selfie_path) : null;
        // Decided requests have no selfie any more — that is by design.
        abort_if($bytes === null, 404);

        $this->audit->record($viewer, 'verification.selfie_viewed', $verificationRequest);

        return response($bytes, 200, [
            'Content-Type' => 'image/jpeg',
            'Cache-Control' => 'no-store, private',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }
}
