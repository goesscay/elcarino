<?php

namespace App\Http\Resources\Safety;

use App\Http\Resources\Profile\ProfilePhotoResource;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * docs/07-ui-ux-design.md §3.7 "Blocked users (Settings child): List with
 * unblock." Deliberately not `MatchedUserResource` — that assumes a
 * completed profile (safe for a match/chat participant, never true for
 * safety features: you can block/report *any* user id, including one with
 * no profile at all yet), so every field here is null-safe instead.
 *
 * @mixin User
 */
class BlockedUserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $profile = $this->profile;
        $photo = $profile?->photos->first();

        return [
            'id' => $this->id,
            'display_name' => $profile?->display_name,
            // A signed URL, same as everywhere else a photo is serialized —
            // `url` isn't a raw model attribute, it's computed by
            // ProfilePhotoResource (the disk is private, docs/06 §6).
            'photo' => $photo ? new ProfilePhotoResource($photo) : null,
        ];
    }
}
