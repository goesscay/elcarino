<?php

namespace Tests\Unit\Services\Calls;

use App\Services\Calls\IceServerResolver;
use Tests\TestCase;

class IceServerResolverTest extends TestCase
{
    public function test_it_includes_the_configured_stun_servers(): void
    {
        config(['services.webrtc.stun_urls' => ['stun:a.example.com:19302', 'stun:b.example.com:19302']]);
        config(['services.webrtc.turn_url' => null]);

        $servers = (new IceServerResolver)->resolve();

        $this->assertSame([
            ['urls' => 'stun:a.example.com:19302'],
            ['urls' => 'stun:b.example.com:19302'],
        ], $servers);
    }

    public function test_it_appends_turn_only_when_configured(): void
    {
        config(['services.webrtc.stun_urls' => ['stun:a.example.com:19302']]);
        config([
            'services.webrtc.turn_url' => 'turn:relay.example.com:3478',
            'services.webrtc.turn_username' => 'user',
            'services.webrtc.turn_credential' => 'secret',
        ]);

        $servers = (new IceServerResolver)->resolve();

        $this->assertSame([
            ['urls' => 'stun:a.example.com:19302'],
            ['urls' => 'turn:relay.example.com:3478', 'username' => 'user', 'credential' => 'secret'],
        ], $servers);
    }
}
