<?php

namespace App\Services\Calls;

/**
 * Builds the `RTCIceServer[]`-shaped array both `CallController::token` and
 * `::answer` hand back to the mobile client — see config('services.webrtc')
 * for why there's no provider-switch pattern here (unlike GifProvider/
 * SmsSender/PushSender) and what's disclosed as not configured (TURN).
 */
class IceServerResolver
{
    /**
     * @return array<int, array{urls: string, username?: string, credential?: string}>
     */
    public function resolve(): array
    {
        $servers = [];

        foreach (config('services.webrtc.stun_urls', []) as $url) {
            $servers[] = ['urls' => $url];
        }

        if (config('services.webrtc.turn_url')) {
            $servers[] = [
                'urls' => config('services.webrtc.turn_url'),
                'username' => config('services.webrtc.turn_username'),
                'credential' => config('services.webrtc.turn_credential'),
            ];
        }

        return $servers;
    }
}
