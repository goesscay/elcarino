<?php

namespace App\Http\Requests\Profile;

use App\Enums\Gender;
use App\Rules\MinimumAge;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ProfileUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'display_name' => ['required', 'string', 'min:1', 'max:50'],
            'birth_date' => ['required', 'date', 'before:today', new MinimumAge],
            'gender' => ['required', Rule::enum(Gender::class)],
            'bio' => ['nullable', 'string', 'max:500'],
            'relationship_goal' => ['nullable', 'string', 'max:100'],
        ];
    }
}
