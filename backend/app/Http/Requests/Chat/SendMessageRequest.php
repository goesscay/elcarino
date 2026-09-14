<?php

namespace App\Http\Requests\Chat;

use Illuminate\Foundation\Http\FormRequest;

class SendMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // `body` is required unless a voice_note or gif is attached —
            // Phase 3 items 1/2 (open decisions #16/#17, both "in scope
            // pending confirmation"). photo (#18) isn't built yet, so this
            // stays an either/or/or rather than a fully generic "exactly one
            // of N" rule for now.
            'body' => [
                'required_without_all:voice_note,gif_id',
                'nullable',
                'string',
                'min:1',
                'max:'.config('chat.max_message_length'),
            ],

            // Shape-level validation only — real mime is re-sniffed
            // server-side (docs/06 §6 "MIME sniff, not trust the extension"),
            // same convention as PhotoUploadRequest.
            'voice_note' => [
                'sometimes',
                'file',
                'mimes:aac,m4a,mp3,mp4,wav,webm,ogg',
                'max:'.config('media.max_voice_note_size_kb'),
                // Only one attachment type per message — docs/07's composer
                // spec ("one attachment type picked at a time"), same
                // constraint the message_attachments migration's
                // message_id-unique index enforces on the voice-note side.
                'prohibits:gif_id',
            ],

            // Client-reported, not server-verified via audio parsing — a
            // disclosed simplification (docs don't require server-side
            // duration verification for this feature). Required whenever a
            // voice_note is present so the recipient's player always has a
            // duration to show before the file itself loads.
            'duration_seconds' => [
                'required_with:voice_note',
                'integer',
                'min:1',
                'max:'.config('media.max_voice_note_duration_seconds'),
            ],

            // The id from a prior GET /gifs/search result — never a raw
            // URL. ChatController::sendMessage re-resolves it server-side
            // via GifProvider::find(), the same "never trust a client-
            // supplied external URL directly" reasoning as not letting the
            // client pick its own subscription plan price.
            'gif_id' => ['sometimes', 'string', 'max:100', 'prohibits:voice_note'],
        ];
    }
}
