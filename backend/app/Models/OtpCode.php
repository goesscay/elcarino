<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * A one-time phone verification code. Never expose `code_hash` — the plaintext
 * code exists only in memory for the duration of the request that generated it
 * (see OtpService) and in the SMS sent to the user.
 */
class OtpCode extends Model
{
    use HasFactory;

    protected $fillable = ['phone', 'code_hash', 'attempts', 'expires_at', 'consumed_at'];

    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'consumed_at' => 'datetime',
        ];
    }

    public function isExpired(): bool
    {
        return $this->expires_at->isPast();
    }

    public function isConsumed(): bool
    {
        return $this->consumed_at !== null;
    }
}
