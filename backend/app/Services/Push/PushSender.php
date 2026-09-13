<?php

namespace App\Services\Push;

/**
 * Provider-agnostic push sender, mirroring `App\Services\Sms\SmsSender`'s
 * shape — spec §18 confirms Firebase Cloud Messaging as the delivery
 * mechanism (not a TBD), but a real send still shouldn't be a hard
 * requirement for local development without a Firebase project configured.
 */
interface PushSender
{
    /**
     * @param  array<string, string>  $data  Extra key/value payload for
     *                                       deep-linking (docs/02's
     *                                       `notifications.payload`, kept
     *                                       as strings — FCM's `data` field
     *                                       requires string values).
     *
     * @throws PushSendException on failure — the caller decides whether that
     *                           should fail the request or just leave
     *                           `sent_via_push` false.
     */
    public function send(string $fcmToken, string $title, string $body, array $data = []): void;
}
