<?php

namespace App\Http\Requests\Swipe;

use App\Enums\SwipeDirection;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SwipeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'target_id' => ['required', 'integer', 'exists:users,id'],
            // `super` accepted (matches the schema enum) but not yet gated,
            // limited, or given a distinct match celebration — Super Like's
            // full behavior is [TBD-11], pending open decision #11.
            'direction' => ['required', Rule::enum(SwipeDirection::class)],
        ];
    }
}
