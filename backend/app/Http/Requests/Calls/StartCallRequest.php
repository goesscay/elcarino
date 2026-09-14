<?php

namespace App\Http\Requests\Calls;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StartCallRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'conversation_id' => ['required', 'integer', 'exists:conversations,id'],
            'type' => ['required', Rule::in(['voice', 'video'])],
        ];
    }
}
