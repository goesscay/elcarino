<?php

namespace App\Http\Requests\Profile;

use Illuminate\Foundation\Http\FormRequest;

class PromptsUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // docs/07-ui-ux-design.md §3.1 Prompts screen: "Pick 3 prompts from
            // the library, answer each (char limit)." Max enforced here; no
            // hard minimum server-side — that's a soft client-side onboarding
            // gate per the same doc's "[TBD — recommend: require 1]".
            'prompts' => ['required', 'array', 'max:'.config('media.max_prompts_per_profile')],
            'prompts.*.prompt_id' => ['required', 'integer', 'distinct', 'exists:profile_prompts,id'],
            'prompts.*.answer' => ['required', 'string', 'min:1', 'max:300'],
        ];
    }
}
