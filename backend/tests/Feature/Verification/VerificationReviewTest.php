<?php

namespace Tests\Feature\Verification;

use App\Enums\NotificationType;
use App\Enums\UserRole;
use App\Enums\VerificationMethod;
use App\Enums\VerificationRejection;
use App\Enums\VerificationStatus;
use App\Models\Profile;
use App\Models\User;
use App\Models\VerificationRequest;
use App\Services\Admin\VerificationModerationService;
use App\Services\Verification\VerificationException;
use App\Services\Verification\VerificationPhotoStore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * The human half of verification (open decision #22): the review queue's
 * service, the audited selfie viewer, and who is allowed near either.
 */
class VerificationReviewTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
    }

    private function moderator(): User
    {
        return User::factory()->create(['role' => UserRole::Moderator]);
    }

    /** A request waiting in the queue, with a real (encrypted) selfie stored. */
    private function queued(): VerificationRequest
    {
        $user = User::factory()->create();
        Profile::factory()->for($user)->create();
        $path = app(VerificationPhotoStore::class)->put("\xFF\xD8\xFF\xE0fake-jpeg-bytes");

        return VerificationRequest::factory()->awaitingReview()->for($user)->create(['selfie_path' => $path]);
    }

    private function service(): VerificationModerationService
    {
        return app(VerificationModerationService::class);
    }

    public function test_approving_verifies_the_profile_notifies_audits_and_deletes_the_selfie(): void
    {
        $reviewer = $this->moderator();
        $request = $this->queued();
        $path = $request->selfie_path;

        $this->service()->approve($reviewer, $request);

        $request->refresh();
        $this->assertSame(VerificationStatus::Approved, $request->status);
        $this->assertNull($request->selfie_path);
        $this->assertFalse(Storage::disk('local')->exists($path));
        $this->assertTrue($request->user->profile->fresh()->is_verified);

        $result = $request->result;
        $this->assertSame('admin', $result->decided_by);
        $this->assertSame($reviewer->id, $result->reviewer_id);
        $this->assertNull($result->reason);

        $this->assertDatabaseHas('notifications', ['user_id' => $request->user_id, 'type' => NotificationType::Verification->value]);
        $this->assertDatabaseHas('audit_log', [
            'actor_id' => $reviewer->id,
            'action' => 'verification.approved',
            'target_type' => $request->getMorphClass(),
            'target_id' => $request->id,
        ]);
    }

    public function test_rejecting_records_the_reason_notifies_audits_and_deletes_the_selfie(): void
    {
        $reviewer = $this->moderator();
        $request = $this->queued();
        $path = $request->selfie_path;

        $this->service()->reject($reviewer, $request, VerificationRejection::FaceMismatch);

        $request->refresh();
        $this->assertSame(VerificationStatus::Rejected, $request->status);
        $this->assertNull($request->selfie_path);
        $this->assertFalse(Storage::disk('local')->exists($path));
        $this->assertFalse($request->user->profile->fresh()->is_verified);
        $this->assertSame('face_mismatch', $request->result->reason);
        $this->assertSame($reviewer->id, $request->result->reviewer_id);

        $this->assertDatabaseHas('audit_log', ['actor_id' => $reviewer->id, 'action' => 'verification.rejected', 'target_id' => $request->id]);
        $this->assertDatabaseHas('notifications', ['user_id' => $request->user_id, 'type' => NotificationType::Verification->value]);
    }

    public function test_a_rejection_tells_the_person_something_they_can_act_on(): void
    {
        $request = $this->queued();

        $this->service()->reject($this->moderator(), $request, VerificationRejection::PhotoUnclear);

        $this->assertStringContainsString('light', VerificationRejection::PhotoUnclear->userMessage());
    }

    public function test_a_request_can_only_be_decided_once(): void
    {
        $reviewer = $this->moderator();
        $request = $this->queued();
        $this->service()->approve($reviewer, $request);

        // A second reviewer clicking the same row moments later.
        $this->expectException(VerificationException::class);
        $this->service()->reject($this->moderator(), $request->fresh(), VerificationRejection::Other);
    }

    public function test_a_stale_copy_of_a_decided_request_cannot_decide_it_again(): void
    {
        // Two reviewers open the same row: both hold a `pending` copy.
        $first = $this->queued();
        $stale = VerificationRequest::query()->findOrFail($first->id);
        $this->service()->approve($this->moderator(), $first);

        try {
            $this->service()->reject($this->moderator(), $stale, VerificationRejection::Other);
            $this->fail('A stale copy decided an already-decided request.');
        } catch (VerificationException $e) {
            $this->assertSame('not_awaiting_review', $e->errorCode);
        }

        $this->assertSame(VerificationStatus::Approved, $first->fresh()->status);
        $this->assertDatabaseCount('verification_results', 1);
        $this->assertDatabaseCount('notifications', 1);
    }

    public function test_a_request_that_is_not_in_the_queue_cannot_be_decided(): void
    {
        $processing = VerificationRequest::factory()->create();

        try {
            $this->service()->approve($this->moderator(), $processing);
            $this->fail('An AI-processing request was approved by a reviewer.');
        } catch (VerificationException $e) {
            $this->assertSame('not_awaiting_review', $e->errorCode);
        }

        $this->assertSame(VerificationMethod::AiSelfie, $processing->fresh()->method);
        $this->assertDatabaseCount('verification_results', 0);
    }

    public function test_only_staff_may_open_the_queue(): void
    {
        $this->assertTrue(Gate::forUser(User::factory()->create(['role' => UserRole::Admin]))->allows('viewAny', VerificationRequest::class));
        $this->assertTrue(Gate::forUser($this->moderator())->allows('viewAny', VerificationRequest::class));
        $this->assertFalse(Gate::forUser(User::factory()->create())->allows('viewAny', VerificationRequest::class));
    }

    public function test_nobody_can_create_edit_or_delete_a_request_from_the_panel(): void
    {
        $admin = User::factory()->create(['role' => UserRole::Admin]);
        $request = $this->queued();

        foreach (['create', 'update', 'delete'] as $ability) {
            $this->assertFalse(Gate::forUser($admin)->allows($ability, $ability === 'create' ? VerificationRequest::class : $request), $ability);
        }
    }

    public function test_a_reviewer_can_view_the_selfie_and_the_view_is_audited(): void
    {
        $reviewer = $this->moderator();
        $request = $this->queued();

        $response = $this->actingAs($reviewer)->get(route('admin.verification.selfie', $request));

        $response->assertOk();
        $this->assertSame("\xFF\xD8\xFF\xE0fake-jpeg-bytes", $response->getContent());
        $this->assertSame('image/jpeg', $response->headers->get('Content-Type'));
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
        $this->assertDatabaseHas('audit_log', [
            'actor_id' => $reviewer->id,
            'action' => 'verification.selfie_viewed',
            'target_id' => $request->id,
        ]);
    }

    public function test_an_ordinary_user_cannot_view_a_selfie(): void
    {
        $request = $this->queued();

        $this->actingAs(User::factory()->create())
            ->get(route('admin.verification.selfie', $request))
            ->assertForbidden();
        $this->assertDatabaseMissing('audit_log', ['action' => 'verification.selfie_viewed']);
    }

    public function test_a_guest_cannot_view_a_selfie(): void
    {
        $request = $this->queued();

        $this->get(route('admin.verification.selfie', $request))->assertForbidden();
        $this->assertDatabaseMissing('audit_log', ['action' => 'verification.selfie_viewed']);
    }

    public function test_a_decided_request_has_no_selfie_to_view(): void
    {
        $reviewer = $this->moderator();
        $request = $this->queued();
        $this->service()->approve($reviewer, $request);

        $this->actingAs($reviewer)->get(route('admin.verification.selfie', $request))->assertNotFound();
    }
}
