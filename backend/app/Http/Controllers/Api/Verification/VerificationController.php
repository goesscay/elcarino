<?php

namespace App\Http\Controllers\Api\Verification;

use App\Enums\VerificationStatus;
use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Verification\SubmitVerificationRequest;
use App\Http\Resources\Verification\VerificationRequestResource;
use App\Services\Media\ImageProcessor;
use App\Services\Media\InvalidImageException;
use App\Services\Verification\VerificationException;
use App\Services\Verification\VerificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class VerificationController extends Controller
{
    use RespondsWithErrorEnvelope;

    public function __construct(
        private readonly VerificationService $verification,
        private readonly ImageProcessor $images,
    ) {}

    /**
     * GET /api/v1/verification/challenge — the pose the selfie must show.
     */
    public function challenge(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->profile?->is_verified) {
            return $this->errorResponse('already_verified', 'Your profile is already verified.', 409);
        }

        $challenge = $this->verification->challenge($user);

        return response()->json(['challenge' => [
            'pose' => $challenge['code'],
            'label' => $challenge['label'],
            'expires_at' => $challenge['expires_at']->toIso8601String(),
        ]]);
    }

    /**
     * POST /api/v1/verification/request — submit the selfie (multipart).
     */
    public function submit(SubmitVerificationRequest $request): JsonResponse
    {
        try {
            $selfie = $this->images->reencode($request->file('selfie'));
        } catch (InvalidImageException $e) {
            return $this->errorResponse('invalid_image', $e->getMessage(), 422);
        }

        try {
            $verification = $this->verification->submit($request->user(), $selfie, $request->string('pose')->toString());
        } catch (VerificationException $e) {
            return $this->errorResponse($e->errorCode, $e->getMessage(), $e->status);
        }

        return response()->json(['request' => new VerificationRequestResource($verification)], 201);
    }

    /**
     * GET /api/v1/verification/status — verified or not, and the latest request.
     */
    public function status(Request $request): JsonResponse
    {
        $user = $request->user();
        $latest = $user->verificationRequests()->with('result')->latest('submitted_at')->latest('id')->first();

        $openOrRecent = $user->verificationRequests()->where('submitted_at', '>', now()->subDay())->count();
        $canStart = ! $user->profile?->is_verified
            && ! ($latest && in_array($latest->status, [VerificationStatus::Pending, VerificationStatus::Processing], true))
            && $openOrRecent < config('verification.max_attempts_per_day');

        return response()->json([
            'is_verified' => (bool) $user->profile?->is_verified,
            'can_start' => $canStart,
            'request' => $latest ? new VerificationRequestResource($latest) : null,
        ]);
    }
}
