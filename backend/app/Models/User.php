<?php

namespace App\Models;

use App\Enums\UserRole;
use App\Enums\UserStatus;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['email', 'phone', 'password', 'google_id', 'apple_id'])]
#[Hidden(['password', 'remember_token', 'google_id', 'apple_id'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    /**
     * Mirrors the migration's column defaults. Eloquent does not re-fetch a
     * row after INSERT, so a freshly created (not yet refreshed) instance
     * would otherwise have a null `status`/`role` in memory even though the
     * database applied its default — breaking the enum cast the moment the
     * model is serialized right after creation (e.g. register/login
     * responses). Keep this in sync with the users migration.
     *
     * @var array<string, mixed>
     */
    protected $attributes = [
        'status' => 'active',
        'role' => 'user',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'phone_verified_at' => 'datetime',
            'last_active_at' => 'datetime',
            'password' => 'hashed',
            'status' => UserStatus::class,
            'role' => UserRole::class,
        ];
    }

    public function isSubscriber(): bool
    {
        // Stubbed until the subscriptions feature (Phase 2) lands — spec §16/§17.
        // Never hardcode true here; premium-gated endpoints must fail closed.
        return false;
    }
}
