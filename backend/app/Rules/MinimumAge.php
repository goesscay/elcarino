<?php

namespace App\Rules;

use Carbon\Carbon;
use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

/**
 * 18+ hard gate at signup/profile-edit — open decision #4 (confirmed), spec
 * §5, docs/06-security-architecture.md ("Minor safety" threat). Never relax
 * this without that decision changing.
 */
class MinimumAge implements ValidationRule
{
    public function __construct(private readonly int $minimumAge = 18) {}

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        $birthDate = Carbon::parse((string) $value);

        if ($birthDate->age < $this->minimumAge) {
            $fail("You must be at least {$this->minimumAge} to use this app.");
        }
    }
}
