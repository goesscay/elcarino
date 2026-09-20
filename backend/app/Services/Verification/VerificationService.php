<?php

namespace App\Services\Verification;

use App\Enums\VerificationMethod;
use App\Enums\VerificationRejection;
use App\Enums\VerificationStatus;
use App\Models\User;
use App\Models\VerificationRequest;
use App\Models\VerificationResult;
use App\Services\Notifications\NotificationService;
use Carbon\Carbon;
use Carbon\CarbonInterface;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * Profile verification (docs/01 §15, Phase 4): a selfie showing a server-issued
 * pose is compared to the person's profile photos, and the result earns the
 * verified badge (`profiles.is_verified`, which the Discover card and profile
 * already render).
 *
 * The decision rules — the part that matters, and where the open decisions
 * [TBD-21/22] bite:
 *
 * - The matcher may **approve** on its own, but only at or above
 *   `verification.approve_threshold`.
 * - The matcher may **reject** on its own for exactly one reason: no face was
 *   found (there is nothing to compare, and the person just retakes it).
 * - Everything else — a non-match, a score under the threshold, a provider
 *   error, no matcher configured — is *never* an automatic rejection. The
 *   request becomes `manual_review`/`pending` and waits for a human (#22). A
 *   face-match model saying "different person" is a probabilistic guess that
 *   fails unevenly across skin tones, lighting and cameras; using it alone to
 *   deny a trust badge is the mistake this rule exists to avoid.
 *
 * Selfies are encrypted at rest and deleted the moment a decision is made.
 */
class VerificationService
{
    public function __construct(
        private readonly FaceMatcher $matcher,
        private readonly VerificationPhotoStore $photos,
        private readonly NotificationService $notifications,
    ) {}

    /**
     * The pose the person must show in their selfie. Idempotent: asking again
     * within the TTL returns the same one, so re-opening the screen doesn't
     * change the goalposts.
     *
     * @return array{code: string, label: string, expires_at: CarbonInterface}
     */
    public function challenge(User $user): array
    {
        $key = $this->challengeKey($user);
        $active = Cache::get($key);

        if (! $this->isLive($active)) {
            $expiresAt = now()->addMinutes(config('verification.challenge_ttl_minutes'));
            // Plain scalars only: a cache store that serialises (the `database`
            // driver, and Redis in production) will not hand a Carbon object
            // back, so it can't sit in the cache.
            $active = [
                'code' => Arr::random(array_keys(config('verification.poses'))),
                'expires_at' => $expiresAt->getTimestamp(),
            ];
            Cache::put($key, $active, $expiresAt);
        }

        return [
            'code' => $active['code'],
            'label' => config('verification.poses')[$active['code']],
            'expires_at' => Carbon::createFromTimestamp($active['expires_at']),
        ];
    }

    /**
     * Whether a cached challenge is present and not yet expired.
     */
    private function isLive(mixed $challenge): bool
    {
        return is_array($challenge)
            && isset($challenge['code'], $challenge['expires_at'])
            && $challenge['expires_at'] > now()->getTimestamp();
    }

    /**
     * @param  string  $selfie  JPEG bytes (already re-encoded, EXIF stripped)
     *
     * @throws VerificationException
     */
    public function submit(User $user, string $selfie, string $poseCode): VerificationRequest
    {
        $profile = $user->profile;

        if ($profile?->is_verified) {
            throw new VerificationException('already_verified', 'Your profile is already verified.', 409);
        }

        if (! $profile || ! $profile->photos()->exists()) {
            throw new VerificationException('photo_required', 'Add a profile photo first, so we have something to compare your selfie to.');
        }

        if ($user->verificationRequests()->whereIn('status', [VerificationStatus::Pending, VerificationStatus::Processing])->exists()) {
            throw new VerificationException('verification_in_progress', 'You already have a verification in progress.', 409);
        }

        $recent = $user->verificationRequests()->where('submitted_at', '>', now()->subDay())->count();
        if ($recent >= config('verification.max_attempts_per_day')) {
            throw new VerificationException('too_many_attempts', 'You have reached the daily verification limit. Try again tomorrow.', 429);
        }

        $challenge = Cache::get($this->challengeKey($user));
        if (! $this->isLive($challenge) || $challenge['code'] !== $poseCode) {
            throw new VerificationException('challenge_expired', 'That pose prompt has expired. Get a new one and try again.');
        }
        // Single use: a selfie can't be replayed against the same prompt.
        Cache::forget($this->challengeKey($user));

        $request = VerificationRequest::query()->create([
            'user_id' => $user->id,
            'method' => VerificationMethod::AiSelfie,
            'status' => VerificationStatus::Processing,
            'pose' => $poseCode,
            'selfie_path' => $this->photos->put($selfie),
            'submitted_at' => now(),
        ]);

        $result = $this->match($selfie, $user);
        $request->forceFill(['ai_outcome' => $result->outcome->value, 'ai_score' => $result->score])->save();

        $threshold = config('verification.approve_threshold');

        if ($result->outcome === FaceMatchOutcome::Matched && $result->score !== null && $result->score >= $threshold) {
            $this->approve($request, decidedBy: 'ai', score: $result->score);
        } elseif ($result->outcome === FaceMatchOutcome::NoFace) {
            $this->reject($request, VerificationRejection::NoFaceDetected, decidedBy: 'ai');
        } else {
            $request->forceFill(['method' => VerificationMethod::ManualReview, 'status' => VerificationStatus::Pending])->save();
        }

        return $request->fresh(['result']);
    }

    /**
     * A human approves a request in the review queue.
     *
     * @throws VerificationException
     */
    public function approveByReviewer(User $reviewer, VerificationRequest $request): void
    {
        $this->claimForReview($request);
        $this->approve($request, decidedBy: 'admin', score: $request->ai_score, reviewer: $reviewer);
    }

    /**
     * A human rejects a request in the review queue.
     *
     * @throws VerificationException
     */
    public function rejectByReviewer(User $reviewer, VerificationRequest $request, VerificationRejection $reason): void
    {
        $this->claimForReview($request);
        $this->reject($request, $reason, decidedBy: 'admin', reviewer: $reviewer);
    }

    /**
     * Takes the request out of the review queue for one decision, atomically.
     *
     * Two reviewers can open the same row; a check on the in-memory copy would
     * let both through and decide twice (two results, two notifications). So the
     * claim is a compare-and-swap in the database — `pending` to `processing`
     * only if it is still `pending` and still a manual review — and exactly one
     * caller sees a row change. Works the same on SQLite and PostgreSQL, no
     * locking needed.
     */
    private function claimForReview(VerificationRequest $request): void
    {
        $claimed = VerificationRequest::query()
            ->whereKey($request->id)
            ->where('status', VerificationStatus::Pending)
            ->where('method', VerificationMethod::ManualReview)
            ->update(['status' => VerificationStatus::Processing]);

        if ($claimed !== 1) {
            throw new VerificationException('not_awaiting_review', 'This request is not waiting for review.', 409);
        }

        $request->refresh();
    }

    private function approve(VerificationRequest $request, string $decidedBy, ?float $score, ?User $reviewer = null): void
    {
        DB::transaction(function () use ($request, $decidedBy, $score, $reviewer) {
            $request->forceFill(['status' => VerificationStatus::Approved])->save();
            $this->record($request, $decidedBy, $score, $reviewer, reason: null);
            $request->user->profile?->forceFill(['is_verified' => true])->save();
            $this->discardSelfie($request);
        });

        $this->notifications->notifyVerification($request->user, VerificationStatus::Approved);
    }

    private function reject(VerificationRequest $request, VerificationRejection $reason, string $decidedBy, ?User $reviewer = null): void
    {
        DB::transaction(function () use ($request, $reason, $decidedBy, $reviewer) {
            $request->forceFill(['status' => VerificationStatus::Rejected])->save();
            $this->record($request, $decidedBy, $request->ai_score, $reviewer, $reason->value);
            $this->discardSelfie($request);
        });

        $this->notifications->notifyVerification($request->user, VerificationStatus::Rejected, $reason);
    }

    private function record(VerificationRequest $request, string $decidedBy, ?float $score, ?User $reviewer, ?string $reason): void
    {
        VerificationResult::query()->create([
            'verification_request_id' => $request->id,
            'decided_by' => $decidedBy,
            'confidence_score' => $score,
            'reviewer_id' => $reviewer?->id,
            'reason' => $reason,
            'decided_at' => now(),
        ]);
    }

    /** docs/06 §5: shortest viable retention — the photo goes with the decision. */
    private function discardSelfie(VerificationRequest $request): void
    {
        $this->photos->delete($request->selfie_path);
        $request->forceFill(['selfie_path' => null])->save();
    }

    /**
     * Runs the matcher against the profile photos. A provider failure is an
     * `inconclusive` result (so it goes to a human), not an error the person
     * sees — and nothing about the images is logged.
     */
    private function match(string $selfie, User $user): FaceMatchResult
    {
        $disk = Storage::disk(config('filesystems.default'));
        $references = $user->profile->photos
            ->map(fn ($photo) => $disk->exists($photo->storage_path) ? $disk->get($photo->storage_path) : null)
            ->filter()
            ->values()
            ->all();

        try {
            return $this->matcher->compare($selfie, $references);
        } catch (Throwable $e) {
            Log::warning('Face matcher failed; routing to manual review.', ['user_id' => $user->id, 'error' => $e::class]);

            return new FaceMatchResult(FaceMatchOutcome::Inconclusive);
        }
    }

    private function challengeKey(User $user): string
    {
        return "verification.challenge.{$user->id}";
    }
}
