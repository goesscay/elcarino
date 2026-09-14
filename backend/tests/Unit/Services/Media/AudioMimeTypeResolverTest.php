<?php

namespace Tests\Unit\Services\Media;

use App\Services\Media\AudioMimeTypeResolver;
use Tests\TestCase;

class AudioMimeTypeResolverTest extends TestCase
{
    private AudioMimeTypeResolver $resolver;

    protected function setUp(): void
    {
        parent::setUp();
        $this->resolver = new AudioMimeTypeResolver;
    }

    /**
     * The bug this whole class exists to work around: `finfo` (what
     * `getMimeType()`'s "sniffed" fallback represents here) reports plain
     * AAC-in-MP4 — exactly what `record`'s default encoder on the mobile
     * client produces, and exactly what m4a/mp4 voice notes are — as
     * `video/mp4`, not an `audio/*` type. The extension is what overrides
     * that ambiguous sniff.
     */
    public function test_m4a_and_mp4_extensions_resolve_to_audio_mp4_regardless_of_the_sniffed_type(): void
    {
        $this->assertSame('audio/mp4', $this->resolver->resolve('m4a', 'video/mp4'));
        $this->assertSame('audio/mp4', $this->resolver->resolve('mp4', 'video/mp4'));
        $this->assertSame('audio/mp4', $this->resolver->resolve('M4A', 'video/mp4'));
    }

    public function test_every_mime_accepted_by_send_message_request_resolves_to_an_audio_type(): void
    {
        $this->assertSame('audio/aac', $this->resolver->resolve('aac', 'application/octet-stream'));
        $this->assertSame('audio/mpeg', $this->resolver->resolve('mp3', 'application/octet-stream'));
        $this->assertSame('audio/wav', $this->resolver->resolve('wav', 'application/octet-stream'));
        $this->assertSame('audio/webm', $this->resolver->resolve('webm', 'video/webm'));
        $this->assertSame('audio/ogg', $this->resolver->resolve('ogg', 'application/ogg'));
    }

    public function test_an_unrecognised_or_missing_extension_falls_back_to_the_sniffed_type(): void
    {
        $this->assertSame('application/octet-stream', $this->resolver->resolve('bin', 'application/octet-stream'));
        $this->assertSame('application/octet-stream', $this->resolver->resolve(null, 'application/octet-stream'));
    }
}
