<?php

namespace App\Http\Requests\Safety;

use App\Enums\ReportCategory;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ReportRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'user_id' => ['required', 'integer', 'exists:users,id'],
            'category' => ['required', Rule::enum(ReportCategory::class)],
            'description' => ['nullable', 'string', 'max:2000'],
            // docs/07 §3.7 "Report — detail": "option to also block" — not
            // in docs/03's original body shape, added here in the same
            // commit that builds the endpoint.
            'also_block' => ['nullable', 'boolean'],
        ];
    }
}
