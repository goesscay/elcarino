<?php

namespace Tests\Feature\Verification;

use App\Enums\UserRole;
use App\Enums\VerificationRejection;
use App\Enums\VerificationStatus;
use App\Filament\Resources\VerificationRequests\Pages\ListVerificationRequests;
use App\Models\Profile;
use App\Models\User;
use App\Models\VerificationRequest;
use App\Services\Admin\VerificationModerationService;
use App\Services\Verification\VerificationPhotoStore;
use Filament\Actions\Testing\TestAction;
use Filament\Facades\Filament;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * The review queue as a reviewer uses it in the admin panel: what the table
 * shows by default, and that Approve / Reject work end to end through the page
 * (the services behind them are covered in VerificationReviewTest).
 */
class VerificationQueuePageTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Filament::setCurrentPanel(Filament::getPanel('admin'));
    }

    private function moderator(): User
    {
        return User::factory()->create(['role' => UserRole::Moderator]);
    }

    private function queued(): VerificationRequest
    {
        $user = User::factory()->create();
        Profile::factory()->for($user)->create();
        $path = app(VerificationPhotoStore::class)->put("\xFF\xD8\xFF\xE0bytes");

        return VerificationRequest::factory()->awaitingReview()->for($user)->create(['selfie_path' => $path]);
    }

    public function test_a_reviewer_sees_the_waiting_requests_by_default(): void
    {
        $waiting = $this->queued();
        $decided = VerificationRequest::factory()->create(['status' => VerificationStatus::Approved]);

        Livewire::actingAs($this->moderator())
            ->test(ListVerificationRequests::class)
            ->assertCanSeeTableRecords([$waiting])
            ->assertCanNotSeeTableRecords([$decided]);
    }

    public function test_an_ordinary_user_cannot_open_the_queue(): void
    {
        $this->queued();

        Livewire::actingAs(User::factory()->create())
            ->test(ListVerificationRequests::class)
            ->assertForbidden();
    }

    public function test_approving_from_the_page_verifies_the_person(): void
    {
        $request = $this->queued();

        Livewire::actingAs($this->moderator())
            ->test(ListVerificationRequests::class)
            ->callAction(TestAction::make('approve')->table($request))
            ->assertNotified('Verification approved');

        $this->assertSame(VerificationStatus::Approved, $request->fresh()->status);
        $this->assertTrue($request->user->profile->fresh()->is_verified);
    }

    public function test_rejecting_from_the_page_records_the_chosen_reason(): void
    {
        $request = $this->queued();

        Livewire::actingAs($this->moderator())
            ->test(ListVerificationRequests::class)
            ->callAction(TestAction::make('reject')->table($request), ['reason' => VerificationRejection::PhotoUnclear->value])
            ->assertNotified('Verification rejected');

        $request->refresh();
        $this->assertSame(VerificationStatus::Rejected, $request->status);
        $this->assertSame('photo_unclear', $request->result->reason);
        $this->assertFalse($request->user->profile->fresh()->is_verified);
    }

    public function test_a_request_a_colleague_already_decided_leaves_the_queue(): void
    {
        $request = $this->queued();
        $moderator = $this->moderator();
        Livewire::actingAs($moderator)->test(ListVerificationRequests::class)->assertCanSeeTableRecords([$request]);

        // A colleague approves it. (Deciding the same row twice is refused at
        // the service — see VerificationReviewTest's stale-copy test.)
        app(VerificationModerationService::class)->approve($this->moderator(), $request);

        Livewire::actingAs($moderator)
            ->test(ListVerificationRequests::class)
            ->assertCanNotSeeTableRecords([$request]);
    }
}
