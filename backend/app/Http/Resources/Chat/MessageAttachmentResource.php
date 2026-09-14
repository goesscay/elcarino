<?php

namespace App\Http\Resources\Chat;

use App\Models\MessageAttachment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

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
            'url' => Storage::disk(config('filesystems.default'))
                ->temporaryUrl(
                    $this->storage_path,
                    now()->addMinutes((int) config('media.chat_media_signed_url_ttl_minutes')),
                ),
            'mime_type' => $this->mime_type,
            'duration_seconds' => $this->duration_seconds,
        ];
    }
}
