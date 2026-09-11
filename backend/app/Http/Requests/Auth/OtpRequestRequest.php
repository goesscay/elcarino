<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class OtpRequestRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // E.164, e.g. +60123456789 — leading + then 8-15 digits.
            'phone' => ['required', 'string', 'regex:/^\+[1-9]\d{7,14}$/'],
        ];
    }
}
