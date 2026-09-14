<?php

namespace Tests\Feature\Chat;

use App\Models\MessageAttachment;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
use Tests\TestCase;

/**
 * `MessageAttachmentStreamController` — the fix for voice-note playback
 * failing on Android's native `MediaPlayer` (see the controller's own doc
 * comment for the full story). These tests cover what actually mattered for
 * that bug — `Range`/`206` support and an explicit `Content-Type` — plus the
 * signature is the only auth check here, so it needs to actually reject a
 * bad one.
 */
class MessageAttachmentStreamTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
    }

    private function attachmentWithFile(
        string $path,
        string $mimeType,
        string $contents = 'fake-audio-bytes',
    ): MessageAttachment {
        Storage::disk('local')->put($path, $contents);

        return MessageAttachment::factory()->create([
            'storage_path' => $path,
            'mime_type' => $mimeType,
        ]);
    }

    private function signedUrlFor(MessageAttachment $attachment): string
    {
        return URL::temporarySignedRoute(
            'media.message-attachments.show',
            now()->addMinutes(5),
            ['attachment' => $attachment->id],
        );
    }

    public function test_a_validly_signed_url_serves_the_file_with_the_stored_content_type(): void
    {
        $attachment = $this->attachmentWithFile('voice-notes/1/a.m4a', 'audio/mp4');

        $response = $this->get($this->signedUrlFor($attachment));

        $response->assertOk();
        $response->assertHeader('Content-Type', 'audio/mp4');
        $response->assertHeader('Accept-Ranges', 'bytes');
    }

    /**
     * The other half of the actual bug: the old `storage.local` route always
     * answered `200` regardless of a `Range` header. A native media player
     * streaming this URL needs a real `206`.
     */
    public function test_a_range_request_gets_a_partial_response(): void
    {
        $attachment = $this->attachmentWithFile('voice-notes/1/b.m4a', 'audio/mp4', str_repeat('x', 1000));

        $response = $this->withHeaders(['Range' => 'bytes=0-99'])
            ->get($this->signedUrlFor($attachment));

        $response->assertStatus(206);
        $response->assertHeader('Content-Range', 'bytes 0-99/1000');
    }

    public function test_an_unsigned_url_is_rejected(): void
    {
        $attachment = $this->attachmentWithFile('voice-notes/1/c.m4a', 'audio/mp4');

        $this->get("/media/message-attachments/{$attachment->id}")->assertForbidden();
    }

    public function test_a_tampered_signature_is_rejected(): void
    {
        $attachment = $this->attachmentWithFile('voice-notes/1/d.m4a', 'audio/mp4');

        $this->get($this->signedUrlFor($attachment).'0')->assertForbidden();
    }

    public function test_a_missing_file_on_disk_returns_404(): void
    {
        $attachment = MessageAttachment::factory()->create(['storage_path' => 'voice-notes/1/missing.m4a']);

        $this->get($this->signedUrlFor($attachment))->assertNotFound();
    }
}
