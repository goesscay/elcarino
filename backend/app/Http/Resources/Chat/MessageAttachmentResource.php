<?php

namespace App\Http\Resources\Chat;

use App\Models\MessageAttachment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;

/**
 * @mixin MessageAttachment
 */
class MessageAttachmentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            // A short-lived signed URL, never the raw storage_path — the
            // disk is private (docs/06 §6). Shorter TTL than
            // ProfilePhotoResource's, per config('media.chat_media_signed_url_ttl_minutes').
            'url' => $this->signedUrl(),
            'mime_type' => $this->mime_type,
            'duration_seconds' => $this->duration_seconds,
        ];
    }

    /**
     * The `local` disk (dev) goes through a dedicated signed route instead
     * of `Storage::temporaryUrl()`'s built-in `storage.local` — see
     * `MessageAttachmentStreamController`'s doc comment for why (no `Range`
     * support, `Content-Type` re-sniffed as `video/mp4` for an AAC-in-MP4
     * voice note; both broke playback on Android's native `MediaPlayer`,
     * confirmed live). A real cloud disk (`s3`, staging/prod) doesn't have
     * either problem — S3 presigned URLs already support `Range` and are
     * served with the object's stored `Content-Type` — so it keeps using
     * `temporaryUrl()` unchanged, same as `ProfilePhotoResource`.
     */
    private function signedUrl(): string
    {
        $ttl = now()->addMinutes((int) config('media.chat_media_signed_url_ttl_minutes'));

        if (config('filesystems.default') === 'local') {
            return URL::temporarySignedRoute(
                'media.message-attachments.show',
                $ttl,
                ['attachment' => $this->id],
            );
        }

        return Storage::disk(config('filesystems.default'))
            ->temporaryUrl($this->storage_path, $ttl);
    }
}
