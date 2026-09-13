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
            // Text only — Phase 1 item 8's explicit scope (voice_note/gif/
            // photo are open decisions #16-18, unconfirmed).
            'body' => ['required', 'string', 'min:1', 'max:'.config('chat.max_message_length')],
        ];
    }
}
