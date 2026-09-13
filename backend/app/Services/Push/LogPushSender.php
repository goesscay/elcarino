<?php

namespace App\Services\Push;

use Illuminate\Support\Facades\Log;

/**
 * Default local-dev sender (PUSH_PROVIDER=log in .env.example). Writes the
 * notification to the log instead of calling FCM — same role as
 * `App\Services\Sms\LogSmsSender` for OTP.
 */
class LogPushSender implements PushSender
{
    public function send(string $fcmToken, string $title, string $body, array $data = []): void
    {
        Log::channel(config('logging.default'))->info('Push notification (log driver)', [
            'fcm_token' => $fcmToken,
            'title' => $title,
            'body' => $body,
            'data' => $data,
        ]);
    }
}
