<?php

namespace App\Http\Requests\Profile;

use Illuminate\Foundation\Http\FormRequest;

class PhotoUploadRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Shape-level validation only (real type/mime/size are re-checked
            // server-side by ImageProcessor — docs/06 §6 "MIME sniff, not
            // trust the extension"). `image` + `mimes` here just reject
            // obviously-wrong uploads early with a normal 422.
            'photo' => [
                'required',
                'image',
                'mimes:jpeg,png,webp',
                'max:'.config('media.max_photo_size_kb'),
            ],
        ];
    }
}
