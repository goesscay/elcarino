<?php

namespace App\Http\Requests\Subscriptions;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreSubscriptionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'plan_id' => ['required', 'integer', Rule::exists('subscription_plans', 'id')->where('is_active', true)],
            // Deliberately Rule::in(...), not Rule::enum(SubscriptionProvider::class)
            // — "other" is a valid enum case for schema completeness (open
            // decision #27) but has no verifier/gateway, so it's never a
            // valid client input.
            'provider' => ['required', Rule::in(['stripe', 'app_store', 'play_store'])],
            'receipt' => ['required_if:provider,app_store,play_store', 'string'],
        ];
    }
}
