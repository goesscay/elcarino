<?php

namespace App\Http\Resources\Profile;

use App\Models\ProfilePhoto;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/**
 * @mixin ProfilePhoto
 */
class ProfilePhotoResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            // A short-lived signed URL, never the raw storage_path — the disk
            // is private (docs/06-security-architecture.md §6). Works
            // unchanged on the local disk (Laravel's built-in signed
            // `storage.local` route) and on s3 in staging/prod.
            'url' => Storage::disk(config('filesystems.default'))
                ->temporaryUrl($this->storage_path, now()->addMinutes((int) config('media.signed_url_ttl_minutes'))),
            'sort_order' => $this->sort_order,
            'moderation_status' => $this->moderation_status->value,
        ];
    }
}
