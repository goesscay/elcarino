<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'email' => ['required_without:phone', 'nullable', 'email'],
            'phone' => ['required_without:email', 'nullable', 'string'],
            'password' => ['required', 'string'],
            'device_name' => ['required', 'string', 'max:255'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            if ($this->filled('email') && $this->filled('phone')) {
                $validator->errors()->add('email', 'Provide either an email or a phone, not both.');
            }
        });
    }
}
