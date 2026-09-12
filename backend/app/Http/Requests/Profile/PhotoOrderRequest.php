<?php

namespace App\Http\Requests\Profile;

use Illuminate\Foundation\Http\FormRequest;

class PhotoOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Ownership (each id really belongs to the caller's own photos) is
            // checked in the controller, not here — that's an authorization
            // concern, not a shape one. See ProfilePhotoController::order().
            'photo_ids' => ['required', 'array', 'min:1'],
            'photo_ids.*' => ['integer', 'distinct', 'exists:profile_photos,id'],
        ];
    }
}
