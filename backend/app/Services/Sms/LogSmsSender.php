<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Log;

/**
 * Default local-dev sender (SMS_PROVIDER=log in .env.example). Writes the
 * message to the log instead of sending a real SMS — lets auth/OTP be built
 * and tested end to end before a real provider is wired up.
 */
class LogSmsSender implements SmsSender
{
    public function send(string $phone, string $message): void
    {
        Log::channel(config('logging.default'))->info('SMS (log driver)', [
            'phone' => $phone,
            'message' => $message,
        ]);
    }
}
