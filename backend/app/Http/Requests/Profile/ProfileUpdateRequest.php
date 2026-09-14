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
            // Phase 2 item 2 (docs/01 §8 "Advanced filters"). Setting your
            // own value is free for everyone — only *filtering* other
            // people by it (PreferencesUpdateRequest / DiscoveryFeedService)
            // is premium-gated. Free-form, same reasoning as the filter
            // columns: no value taxonomy exists anywhere in /docs.
            'religion' => ['nullable', 'string', 'max:100'],
            'politics' => ['nullable', 'string', 'max:100'],
        ];
    }
}
