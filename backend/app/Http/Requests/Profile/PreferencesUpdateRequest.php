<?php

namespace App\Http\Requests\Profile;

use App\Enums\Gender;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PreferencesUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'min_age' => ['required', 'integer', 'min:18', 'max:99'],
            'max_age' => ['required', 'integer', 'gte:min_age', 'max:100'],
            // Platform cap — open decision #8 working assumption ("assume 200 km max").
            'max_distance_km' => ['required', 'integer', 'min:1', 'max:200'],
            'interested_in_genders' => ['required', 'array', 'min:1'],
            'interested_in_genders.*' => [Rule::enum(Gender::class)],
            // Religion/politics value taxonomies are not defined anywhere in
            // /docs (decision #10 only confirms the filters must exist, not
            // their option lists) — accepted here as free-form strings rather
            // than an invented enum. Flag if the client wants fixed lists.
            'religion_filter' => ['nullable', 'array', 'max:10'],
            'religion_filter.*' => ['string', 'max:50'],
            'politics_filter' => ['nullable', 'array', 'max:10'],
            'politics_filter.*' => ['string', 'max:50'],
            'relationship_goal_filter' => ['nullable', 'array', 'max:10'],
            'relationship_goal_filter.*' => ['string', 'max:50'],
        ];
    }
}
