<?php

namespace App\Services\Media;

/**
 * `UploadedFile::getMimeType()` sniffs via `finfo` on the actual bytes,
 * which reports plain AAC-in-MP4 audio (what `record`'s default
 * `AudioEncoder.aacLc` produces on the mobile client, and what
 * `SendMessageRequest`'s `mimes:` rule already restricts this field to) as
 * `video/mp4` — the ISO base media container doesn't unambiguously say
 * "audio-only" without deeper track inspection, and libmagic doesn't do
 * that. Confirmed live: a real recording's `finfo`-sniffed `video/mp4`,
 * stored as-is and served back as the response `Content-Type`, broke
 * playback on Android's native `MediaPlayer` — see
 * `MessageAttachmentStreamController`'s doc comment.
 *
 * `ChatController::sendMessage` only ever calls this for a voice note (the
 * only attachment type built so far — #17/#18 unconfirmed), so the
 * extension is a safe, unambiguous source of truth here: it's itself
 * derived from the sniffed bytes by `SendMessageRequest`'s `mimes:` rule
 * (via Symfony's `guessExtension()`), not the client-supplied filename.
 */
class AudioMimeTypeResolver
{
    private const MIME_TYPES_BY_EXTENSION = [
        'aac' => 'audio/aac',
        'm4a' => 'audio/mp4',
        'mp4' => 'audio/mp4',
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'webm' => 'audio/webm',
        'ogg' => 'audio/ogg',
    ];

    /**
     * @param  string|null  $extension  e.g. `UploadedFile::extension()`.
     * @param  string  $sniffedMimeType  e.g. `UploadedFile::getMimeType()` —
     *                                   the fallback when the extension isn't one of the known audio types
     *                                   above (shouldn't happen given `SendMessageRequest`'s `mimes:` rule,
     *                                   but a resolver that only ever narrows a set of known-good inputs,
     *                                   rather than one that can throw on an unexpected one, is the safer
     *                                   shape here).
     */
    public function resolve(?string $extension, string $sniffedMimeType): string
    {
        return self::MIME_TYPES_BY_EXTENSION[strtolower($extension ?? '')] ?? $sniffedMimeType;
    }
}
