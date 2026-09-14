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
            // `body` is required unless a voice_note is attached — Phase 3
            // item 1 (open decision #16, "in scope pending confirmation").
            // gif/photo (#17/#18) aren't built yet, so this stays a plain
            // either/or rather than a "exactly one of N" rule for now.
            'body' => [
                'required_without:voice_note',
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
        ];
    }
}
