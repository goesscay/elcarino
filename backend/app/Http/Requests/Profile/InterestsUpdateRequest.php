<?php

namespace App\Http\Requests\Profile;

use Illuminate\Foundation\Http\FormRequest;

class InterestsUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // `present`, not `required` — an empty array is a valid "clear all
            // my interests" request, it just has to actually be sent.
            'interest_ids' => ['present', 'array', 'max:'.config('media.max_interests_per_profile')],
            'interest_ids.*' => ['integer', 'distinct', 'exists:interests,id'],
        ];
    }
}
