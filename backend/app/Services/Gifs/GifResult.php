<?php

namespace App\Services\Gifs;

/**
 * A single GIF, provider-agnostic. `previewUrl` is a small/thumbnail
 * rendition for the search grid (GifController::search); `url` is the
 * larger rendition actually sent in the chat message body — both are
 * stable, public, third-party-hosted URLs, never re-hosted on our own disk
 * (unlike voice notes/photos — see ChatController::sendMessage's doc
 * comment on why gif messages don't use message_attachments at all).
 */
readonly class GifResult
{
    public function __construct(
        public string $id,
        public string $previewUrl,
        public string $url,
        public int $width,
        public int $height,
    ) {}
}
