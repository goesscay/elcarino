<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Default real-world provider (open decision: SMS/OTP provider — see
 * docs/05-open-decisions.md). Confirm before relying on this in production;
 * swap the SmsSender binding in AppServiceProvider if a different provider is
 * chosen — nothing else in the auth feature depends on Twilio specifically.
 */
class TwilioSmsSender implements SmsSender
{
    public function __construct(
        private readonly ?string $sid = null,
        private readonly ?string $token = null,
        private readonly ?string $from = null,
    ) {}

    public function send(string $phone, string $message): void
    {
        if (! $this->sid || ! $this->token || ! $this->from) {
            throw new RuntimeException(
                'TWILIO_SID / TWILIO_TOKEN / TWILIO_FROM are not configured. '.
                'Set them in .env, or switch SMS_PROVIDER=log for local development.'
            );
        }

        $response = Http::asForm()
            ->withBasicAuth($this->sid, $this->token)
            ->post("https://api.twilio.com/2010-04-01/Accounts/{$this->sid}/Messages.json", [
                'To' => $phone,
                'From' => $this->from,
                'Body' => $message,
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Twilio SMS send failed: '.$response->body());
        }
    }
}
