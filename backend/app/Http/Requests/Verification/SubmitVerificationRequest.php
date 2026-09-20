<?php

namespace App\Http\Requests\Verification;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SubmitVerificationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // The pose code from GET /verification/challenge. The service
            // checks it is the *currently issued* one for this user; this only
            // rejects a code that could never be valid.
            'pose' => ['required', 'string', Rule::in(array_keys(config('verification.poses')))],
            // Shape-level only — real type/size are re-checked by
            // ImageProcessor (docs/06 §6: MIME sniff, re-encode, EXIF strip).
            'selfie' => ['required', 'image', 'mimes:jpeg,png,webp', 'max:'.config('verification.max_selfie_size_kb')],
        ];
    }
}
