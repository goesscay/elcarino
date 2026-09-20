<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

/**
 * verification_requests.status (docs/02). `processing` while the matcher runs;
 * `pending` once it needs a human; the other two are terminal.
 */
enum VerificationStatus: string implements HasColor, HasLabel
{
    case Pending = 'pending';
    case Processing = 'processing';
    case Approved = 'approved';
    case Rejected = 'rejected';

    /** Still waiting on something — the user can't submit another request. */
    public function isOpen(): bool
    {
        return in_array($this, [self::Pending, self::Processing], true);
    }

    public function getLabel(): string
    {
        return ucfirst($this->value);
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Pending => 'warning',
            self::Processing => 'info',
            self::Approved => 'success',
            self::Rejected => 'danger',
        };
    }
}
