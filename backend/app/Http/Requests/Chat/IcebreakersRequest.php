<?php

namespace App\Http\Requests\Chat;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Authorises both icebreaker endpoints through ConversationPolicy::icebreakers
 * (participant, not blocked either way, both accounts active — the same bar as
 * sending a message, since a suggestion is only useful where you could send it).
 * There is no body to validate.
 */
class IcebreakersRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('icebreakers', $this->route('conversation'));
    }

    public function rules(): array
    {
        return [];
    }
}
