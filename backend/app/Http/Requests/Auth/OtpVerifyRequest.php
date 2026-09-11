<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class OtpVerifyRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'phone' => ['required', 'string', 'regex:/^\+[1-9]\d{7,14}$/'],
            'code' => ['required', 'string', 'size:6'],
            'device_name' => ['required', 'string', 'max:255'],
        ];
    }
}
