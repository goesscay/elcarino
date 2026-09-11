<?php

namespace App\Services\Auth;

use App\Models\OtpCode;
use App\Services\Sms\SmsSender;
use Illuminate\Support\Facades\Hash;

/**
 * Generates, stores and verifies phone OTP codes.
 * See docs/06-security-architecture.md §2.2 for the security rules this
 * implements: hashed at rest, short TTL, single use, bounded attempts.
 */
class OtpService
{
    public function __construct(
        private readonly SmsSender $sms,
        private readonly int $ttlSeconds = 300,
        private readonly int $maxAttempts = 5,
    ) {}

    public function requestCode(string $phone): void
    {
        $code = (string) random_int(100000, 999999);

        OtpCode::create([
            'phone' => $phone,
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addSeconds($this->ttlSeconds),
        ]);

        $this->sms->send($phone, "Your DatingApp verification code is {$code}. It expires in ".intdiv($this->ttlSeconds, 60).' minutes.');
    }

    /**
     * @return bool true if the code was valid and has now been consumed.
     */
    public function verifyCode(string $phone, string $code): bool
    {
        /** @var OtpCode|null $otp */
        $otp = OtpCode::query()
            ->where('phone', $phone)
            ->whereNull('consumed_at')
            ->latest('id')
            ->first();

        if (! $otp || $otp->isExpired() || $otp->attempts >= $this->maxAttempts) {
            return false;
        }

        if (! Hash::check($code, $otp->code_hash)) {
            $otp->increment('attempts');

            return false;
        }

        $otp->forceFill(['consumed_at' => now()])->save();

        return true;
    }
}
