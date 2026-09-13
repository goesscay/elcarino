<?php

namespace App\Http\Requests\Discovery;

use Illuminate\Foundation\Http\FormRequest;

class DiscoveryFeedRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:'.config('discovery.max_per_page')],
            // Accepted but currently a no-op — there is no feed cache yet for
            // it to bust. docs/03: "force a fresh batch (e.g. after boost
            // activation)"; boosts don't exist until Phase 2.
            'refresh' => ['sometimes', 'boolean'],
        ];
    }

    public function page(): int
    {
        return (int) $this->input('page', 1);
    }

    public function perPage(): int
    {
        return (int) $this->input('per_page', config('discovery.default_per_page'));
    }
}
