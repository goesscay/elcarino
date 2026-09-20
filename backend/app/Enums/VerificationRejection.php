<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

/**
 * Why a verification was rejected — `verification_results.reason`. Each has
 * copy that is safe to show the person (docs/07 §3.6 "reason (if safe to
 * show)"): none of them accuses, and none reveals how a decision was reached.
 */
enum VerificationRejection: string implements HasLabel
{
    /** The only reason the AI path may auto-reject: nothing to compare. */
    case NoFaceDetected = 'no_face_detected';
    case FaceMismatch = 'face_mismatch';
    case PhotoUnclear = 'photo_unclear';
    case PoseNotFollowed = 'pose_not_followed';
    case Other = 'other';

    public function getLabel(): string
    {
        return match ($this) {
            self::NoFaceDetected => 'No face detected',
            self::FaceMismatch => 'Face does not match profile photos',
            self::PhotoUnclear => 'Photo unclear',
            self::PoseNotFollowed => 'Pose not followed',
            self::Other => 'Other',
        };
    }

    /** What the person sees. */
    public function userMessage(): string
    {
        return match ($this) {
            self::NoFaceDetected => "We couldn't see a face in your selfie. Try again in good light, facing the camera.",
            self::FaceMismatch => "We couldn't match your selfie to your profile photos. Make sure your profile photos show you, then try again.",
            self::PhotoUnclear => 'Your selfie was too dark or blurry to check. Try again in better light.',
            self::PoseNotFollowed => "Your selfie didn't show the pose we asked for. Try again and follow the prompt.",
            self::Other => "We couldn't verify you this time. You can try again.",
        };
    }
}
