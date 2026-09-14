<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

enum UserRole: string implements HasColor, HasLabel
{
    case User = 'user';
    case Moderator = 'moderator';
    case Admin = 'admin';

    /**
     * Presentational only (Filament badge label/color, Phase 1 item 11).
     */
    public function getLabel(): string
    {
        return match ($this) {
            self::User => 'User',
            self::Moderator => 'Moderator',
            self::Admin => 'Admin',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::User => 'gray',
            self::Moderator => 'info',
            self::Admin => 'primary',
        };
    }
}
