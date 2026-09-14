<?php

namespace App\Http\Controllers\Media;

use App\Http\Controllers\Controller;
use App\Models\MessageAttachment;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * GET `media/message-attachments/{attachment}` — signed, short-lived
 * (`media.chat_media_signed_url_ttl_minutes`), only ever reached via the URL
 * `MessageAttachmentResource` mints. The `signed` route middleware is the
 * entire auth check here — no separate `ConversationPolicy` lookup — the
 * same security model `storage.local` (profile photos) already uses: the
 * capability lives in the signature, not a second per-request permission
 * check, per docs/06-security-architecture.md §6.
 *
 * A dedicated route rather than reusing `Storage::temporaryUrl()`'s built-in
 * `storage.local` route (still used for the `local`-disk fallback nowhere —
 * see `MessageAttachmentResource`): that route streams through
 * `Illuminate\Http\Response` (`FilesystemAdapter::serve()` →
 * `StreamedResponse`), which never sets `Accept-Ranges` and always answers a
 * `Range` request with a full `200`, and it sets `Content-Type` by
 * re-sniffing the file's bytes via `finfo`, which reports an AAC-in-MP4
 * voice note as `video/mp4` (the container doesn't unambiguously say
 * "audio-only" without deeper track inspection). Both together broke
 * playback on Android's native `MediaPlayer` — confirmed live on the
 * emulator: `curl` downloaded the exact same signed URL cleanly, but
 * `adb logcat` showed `NuCachedSource2: source returned error -1`, and a
 * manual `Range: bytes=0-` probe against the old URL came back a plain `200`
 * with no `Accept-Ranges` header.
 *
 * `response()->file()` returns a Symfony `BinaryFileResponse`, which
 * implements `Range`/`206`/`Accept-Ranges`/`ETag`/`Last-Modified` itself,
 * and `mime_type` is passed through explicitly from the attachment's own
 * stored column (set from the upload's sniffed type at write time —
 * `ChatController::sendMessage`) instead of being re-sniffed from the file
 * on every serve.
 */
class MessageAttachmentStreamController extends Controller
{
    public function show(MessageAttachment $attachment): BinaryFileResponse
    {
        $disk = Storage::disk(config('filesystems.default'));

        abort_unless($disk->exists($attachment->storage_path), 404);

        $response = response()->file($disk->path($attachment->storage_path), [
            'Content-Type' => $attachment->mime_type,
        ]);

        // Never cached by an intermediary or the OS media stack across a
        // reissued signed URL for the same path — matches ServeFile's own
        // header for storage.local (profile photos).
        $response->headers->set(
            'Cache-Control',
            'no-store, no-cache, must-revalidate, max-age=0',
        );

        return $response;
    }
}
