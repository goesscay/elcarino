<?php

namespace Tests\Feature\Verification;

use App\Enums\NotificationType;
use App\Enums\VerificationMethod;
use App\Enums\VerificationStatus;
use App\Models\Profile;
use App\Models\User;
use App\Models\VerificationRequest;
use App\Services\Verification\FaceMatcher;
use App\Services\Verification\FaceMatchOutcome;
use App\Services\Verification\FaceMatchResult;
use App\Services\Verification\FakeFaceMatcher;
use App\Services\Verification\UnconfiguredFaceMatcher;
use App\Services\Verification\VerificationPhotoStore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * The verification API and its decision rules (docs/01 §15). The properties
 * that matter: the AI can approve (at the threshold) or reject only for "no
 * face"; anything else waits for a human and is never an automatic rejection;
 * the selfie is encrypted while it lives and gone once decided; and the person
 * never sees the matcher's score.
 */
class VerificationApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Selfies and profile photos go through the storage disk; never the real one.
        Storage::fake('local');
    }

    private function user(bool $withPhoto = true, bool $verified = false): User
    {
        $user = User::factory()->create();
        $profile = Profile::factory()->for($user)->create();
        if ($verified) {
            $profile->forceFill(['is_verified' => true])->save();
        }
        if ($withPhoto) {
            $profile->photos()->create(['storage_path' => "photos/{$user->id}/main.jpg", 'sort_order' => 0]);
            Storage::disk('local')->put("photos/{$user->id}/main.jpg", 'profile-photo-bytes');
        }

        return $user;
    }

    private function matcher(FaceMatchOutcome $outcome, ?float $score = null): void
    {
        $this->app->instance(FaceMatcher::class, new FakeFaceMatcher($outcome, $score ?? 0));
    }

    /** Asks for a challenge, then submits a selfie showing it. */
    private function submitSelfie(User $user, ?string $pose = null)
    {
        Sanctum::actingAs($user);
        $pose ??= $this->getJson('/api/v1/verification/challenge')->json('challenge.pose');

        return $this->postJson('/api/v1/verification/request', [
            'pose' => $pose,
            'selfie' => UploadedFile::fake()->image('selfie.jpg', 300, 300),
        ]);
    }

    public function test_a_guest_cannot_use_any_endpoint(): void
    {
        $this->getJson('/api/v1/verification/challenge')->assertUnauthorized();
        $this->postJson('/api/v1/verification/request')->assertUnauthorized();
        $this->getJson('/api/v1/verification/status')->assertUnauthorized();
    }

    public function test_the_challenge_is_a_known_pose_and_stable_within_its_lifetime(): void
    {
        Sanctum::actingAs($this->user());

        $first = $this->getJson('/api/v1/verification/challenge')->assertOk();
        $second = $this->getJson('/api/v1/verification/challenge')->assertOk();

        $this->assertArrayHasKey($first->json('challenge.pose'), config('verification.poses'));
        $this->assertSame(config('verification.poses')[$first->json('challenge.pose')], $first->json('challenge.label'));
        $this->assertSame($first->json('challenge.pose'), $second->json('challenge.pose'));
    }

    public function test_the_flow_works_on_a_cache_store_that_serialises(): void
    {
        // The array store used elsewhere in tests never serialises, which hid a
        // real bug: a Carbon object in the cache comes back "incomplete" from the
        // `database` driver (dev) and Redis (production).
        config(['cache.default' => 'database']);
        $this->matcher(FaceMatchOutcome::Matched, 97);

        $this->submitSelfie($this->user())->assertCreated()->assertJsonPath('request.status', 'approved');
    }

    public function test_a_verified_user_gets_no_challenge(): void
    {
        Sanctum::actingAs($this->user(verified: true));

        $this->getJson('/api/v1/verification/challenge')
            ->assertStatus(409)->assertJsonPath('error.code', 'already_verified');
    }

    public function test_a_confident_match_is_approved_and_the_selfie_is_deleted(): void
    {
        $this->matcher(FaceMatchOutcome::Matched, 97);
        $user = $this->user();

        $response = $this->submitSelfie($user)->assertCreated();

        $response->assertJsonPath('request.status', 'approved')->assertJsonPath('request.reason', null);
        $this->assertTrue($user->profile->fresh()->is_verified);

        $request = VerificationRequest::query()->firstOrFail();
        $this->assertSame(VerificationStatus::Approved, $request->status);
        $this->assertNull($request->selfie_path);
        $this->assertSame([], Storage::disk('local')->files('verification'));

        $result = $request->result;
        $this->assertSame('ai', $result->decided_by);
        $this->assertSame(97.0, $result->confidence_score);
        $this->assertNull($result->reviewer_id);

        $this->assertDatabaseHas('notifications', ['user_id' => $user->id, 'type' => NotificationType::Verification->value]);
    }

    public function test_a_match_below_the_threshold_goes_to_a_human(): void
    {
        $this->matcher(FaceMatchOutcome::Matched, 80);
        $user = $this->user();

        $this->submitSelfie($user)->assertCreated()->assertJsonPath('request.status', 'in_review');

        $request = VerificationRequest::query()->firstOrFail();
        $this->assertSame(VerificationMethod::ManualReview, $request->method);
        $this->assertSame(VerificationStatus::Pending, $request->status);
        $this->assertFalse($user->profile->fresh()->is_verified);
        // Kept for the reviewer, but encrypted at rest.
        $this->assertNotNull($request->selfie_path);
        $this->assertCount(1, Storage::disk('local')->files('verification'));
    }

    public function test_a_stored_selfie_is_encrypted_and_round_trips(): void
    {
        $this->matcher(FaceMatchOutcome::Inconclusive);
        $this->submitSelfie($this->user())->assertCreated();

        $request = VerificationRequest::query()->firstOrFail();
        $raw = Storage::disk('local')->get($request->selfie_path);

        // Not a JPEG on disk (FF D8 magic), yet the store can read it back.
        $this->assertStringStartsNotWith("\xFF\xD8", $raw);
        $decrypted = app(VerificationPhotoStore::class)->get($request->selfie_path);
        $this->assertStringStartsWith("\xFF\xD8", $decrypted);
    }

    public function test_a_non_match_is_never_an_automatic_rejection(): void
    {
        $this->matcher(FaceMatchOutcome::NotMatched);
        $user = $this->user();

        $this->submitSelfie($user)->assertCreated()->assertJsonPath('request.status', 'in_review');

        $this->assertSame(VerificationStatus::Pending, VerificationRequest::query()->firstOrFail()->status);
        $this->assertDatabaseCount('verification_results', 0);
    }

    public function test_an_inconclusive_result_goes_to_a_human(): void
    {
        $this->matcher(FaceMatchOutcome::Inconclusive);

        $this->submitSelfie($this->user())->assertCreated()->assertJsonPath('request.status', 'in_review');
    }

    public function test_with_no_provider_configured_everything_goes_to_a_human(): void
    {
        $this->app->instance(FaceMatcher::class, new UnconfiguredFaceMatcher);

        $this->submitSelfie($this->user())->assertCreated()->assertJsonPath('request.status', 'in_review');
        $this->assertFalse(Profile::query()->where('is_verified', true)->exists());
    }

    public function test_a_provider_failure_goes_to_a_human_not_to_the_user(): void
    {
        $this->app->instance(FaceMatcher::class, new class implements FaceMatcher
        {
            public function compare(string $selfie, array $references): FaceMatchResult
            {
                throw new \RuntimeException('provider down');
            }
        });

        $this->submitSelfie($this->user())->assertCreated()->assertJsonPath('request.status', 'in_review');
    }

    public function test_no_face_is_the_one_automatic_rejection(): void
    {
        $this->matcher(FaceMatchOutcome::NoFace);
        $user = $this->user();

        $response = $this->submitSelfie($user)->assertCreated();

        $response->assertJsonPath('request.status', 'rejected')->assertJsonPath('request.reason', 'no_face_detected');
        $this->assertStringContainsString('face', $response->json('request.reason_message'));
        $request = VerificationRequest::query()->firstOrFail();
        $this->assertNull($request->selfie_path);
        $this->assertSame([], Storage::disk('local')->files('verification'));
        $this->assertSame('ai', $request->result->decided_by);
        $this->assertFalse($user->profile->fresh()->is_verified);
        $this->assertDatabaseHas('notifications', ['user_id' => $user->id, 'type' => NotificationType::Verification->value]);
    }

    public function test_the_response_never_exposes_the_score_outcome_or_selfie(): void
    {
        $this->matcher(FaceMatchOutcome::Matched, 97);

        $body = $this->submitSelfie($this->user())->assertCreated()->getContent();

        foreach (['ai_score', 'ai_outcome', 'confidence', 'selfie_path', 'reviewer', '97'] as $secret) {
            $this->assertStringNotContainsString($secret, $body);
        }
    }

    public function test_a_selfie_and_pose_are_required_and_validated(): void
    {
        Sanctum::actingAs($this->user());
        $this->getJson('/api/v1/verification/challenge');

        $this->postJson('/api/v1/verification/request', [])->assertStatus(422)->assertJsonValidationErrors(['pose', 'selfie']);
        $this->postJson('/api/v1/verification/request', [
            'pose' => 'not_a_pose',
            'selfie' => UploadedFile::fake()->image('s.jpg'),
        ])->assertStatus(422)->assertJsonValidationErrors(['pose']);
        $this->postJson('/api/v1/verification/request', [
            'pose' => 'thumbs_up',
            'selfie' => UploadedFile::fake()->create('s.pdf', 10, 'application/pdf'),
        ])->assertStatus(422)->assertJsonValidationErrors(['selfie']);
    }

    public function test_the_pose_must_be_the_one_currently_issued(): void
    {
        $this->matcher(FaceMatchOutcome::Matched, 99);
        $user = $this->user();
        Sanctum::actingAs($user);
        $issued = $this->getJson('/api/v1/verification/challenge')->json('challenge.pose');
        $other = collect(array_keys(config('verification.poses')))->first(fn ($p) => $p !== $issued);

        $this->submitSelfie($user, $other)->assertStatus(422)->assertJsonPath('error.code', 'challenge_expired');
        $this->assertDatabaseCount('verification_requests', 0);
    }

    public function test_submitting_without_asking_for_a_challenge_fails(): void
    {
        Sanctum::actingAs($this->user());

        $this->postJson('/api/v1/verification/request', [
            'pose' => 'thumbs_up',
            'selfie' => UploadedFile::fake()->image('s.jpg'),
        ])->assertStatus(422)->assertJsonPath('error.code', 'challenge_expired');
    }

    public function test_an_expired_challenge_is_refused(): void
    {
        $this->matcher(FaceMatchOutcome::Matched, 99);
        $user = $this->user();
        Sanctum::actingAs($user);
        $pose = $this->getJson('/api/v1/verification/challenge')->json('challenge.pose');

        $this->travel(config('verification.challenge_ttl_minutes') + 1)->minutes();

        $this->submitSelfie($user, $pose)->assertStatus(422)->assertJsonPath('error.code', 'challenge_expired');
    }

    public function test_a_challenge_is_single_use(): void
    {
        $this->matcher(FaceMatchOutcome::NoFace);
        $user = $this->user();
        $pose = $this->submitSelfie($user)->assertCreated()->json('request.status');
        $this->assertSame('rejected', $pose);

        // Same prompt again, without asking for a new one: refused.
        $issued = VerificationRequest::query()->firstOrFail()->pose;
        $this->submitSelfie($user, $issued)->assertStatus(422)->assertJsonPath('error.code', 'challenge_expired');
    }

    public function test_a_profile_photo_is_required(): void
    {
        Sanctum::actingAs($this->user(withPhoto: false));

        $this->getJson('/api/v1/verification/challenge');
        $this->postJson('/api/v1/verification/request', [
            'pose' => 'thumbs_up',
            'selfie' => UploadedFile::fake()->image('s.jpg'),
        ])->assertStatus(422)->assertJsonPath('error.code', 'photo_required');
    }

    public function test_an_already_verified_user_cannot_submit(): void
    {
        $this->submitSelfie($this->user(verified: true), 'thumbs_up')
            ->assertStatus(409)->assertJsonPath('error.code', 'already_verified');
    }

    public function test_only_one_request_can_be_open_at_a_time(): void
    {
        $this->matcher(FaceMatchOutcome::Inconclusive);
        $user = $this->user();
        $this->submitSelfie($user)->assertCreated();

        $this->submitSelfie($user)->assertStatus(409)->assertJsonPath('error.code', 'verification_in_progress');
        $this->assertDatabaseCount('verification_requests', 1);
    }

    public function test_attempts_are_capped_per_day(): void
    {
        config(['verification.max_attempts_per_day' => 2]);
        $this->matcher(FaceMatchOutcome::NoFace);
        $user = $this->user();
        $this->submitSelfie($user)->assertCreated();
        $this->submitSelfie($user)->assertCreated();

        $this->submitSelfie($user)->assertStatus(429)->assertJsonPath('error.code', 'too_many_attempts');

        // The window rolls: a day later they may try again.
        $this->travel(25)->hours();
        $this->submitSelfie($user)->assertCreated();
    }

    public function test_status_before_any_request(): void
    {
        Sanctum::actingAs($this->user());

        $this->getJson('/api/v1/verification/status')
            ->assertOk()
            ->assertJson(['is_verified' => false, 'can_start' => true, 'request' => null]);
    }

    public function test_status_tracks_the_latest_request(): void
    {
        $this->matcher(FaceMatchOutcome::Inconclusive);
        $user = $this->user();
        $this->submitSelfie($user)->assertCreated();

        $this->getJson('/api/v1/verification/status')
            ->assertOk()
            ->assertJsonPath('is_verified', false)
            ->assertJsonPath('can_start', false)
            ->assertJsonPath('request.status', 'in_review');
    }

    public function test_status_after_approval(): void
    {
        $this->matcher(FaceMatchOutcome::Matched, 99);
        $user = $this->user();
        $this->submitSelfie($user)->assertCreated();
        // A real request loads a fresh user; the acting-as instance caches its profile.
        $user->unsetRelation('profile');

        $this->getJson('/api/v1/verification/status')
            ->assertJsonPath('is_verified', true)
            ->assertJsonPath('can_start', false)
            ->assertJsonPath('request.status', 'approved');
    }

    public function test_status_after_a_rejection_allows_trying_again(): void
    {
        $this->matcher(FaceMatchOutcome::NoFace);
        $user = $this->user();
        $this->submitSelfie($user)->assertCreated();
        $user->unsetRelation('profile');

        $this->getJson('/api/v1/verification/status')
            ->assertJsonPath('is_verified', false)
            ->assertJsonPath('can_start', true)
            ->assertJsonPath('request.status', 'rejected')
            ->assertJsonPath('request.reason', 'no_face_detected');
    }

    public function test_one_user_cannot_see_anothers_request(): void
    {
        $this->matcher(FaceMatchOutcome::Inconclusive);
        $this->submitSelfie($this->user())->assertCreated();

        Sanctum::actingAs($this->user());
        $this->getJson('/api/v1/verification/status')->assertJson(['request' => null]);
    }

    public function test_the_fake_provider_refuses_to_run_in_production(): void
    {
        config(['verification.provider' => 'fake']);
        $this->app['env'] = 'production';

        $this->expectException(\LogicException::class);
        $this->app->make(FaceMatcher::class);
    }

    public function test_the_default_provider_is_the_unconfigured_one(): void
    {
        config(['verification.provider' => 'none']);

        $this->assertInstanceOf(UnconfiguredFaceMatcher::class, $this->app->make(FaceMatcher::class));
    }
}
