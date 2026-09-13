<?php

namespace App\Http\Requests\User;

use Illuminate\Foundation\Http\FormRequest;

class RegisterDeviceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'fcm_token' => ['required', 'string', 'max:255'],
            'platform' => ['required', 'string', 'in:ios,android'],
            'app_version' => ['nullable', 'string', 'max:32'],
        ];
    }
}
