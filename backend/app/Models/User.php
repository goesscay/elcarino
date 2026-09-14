<?php

namespace App\Models;

use App\Enums\UserRole;
use App\Enums\UserStatus;
use Database\Factories\UserFactory;
use Filament\Auth\MultiFactor\App\Contracts\HasAppAuthentication;
use Filament\Auth\MultiFactor\App\Contracts\HasAppAuthenticationRecovery;
use Filament\Models\Contracts\FilamentUser;
use Filament\Models\Contracts\HasName;
use Filament\Panel;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use SensitiveParameter;

#[Fillable(['email', 'phone', 'password', 'google_id', 'apple_id'])]
#[Hidden(['password', 'remember_token', 'google_id', 'apple_id', 'app_authentication_secret', 'app_authentication_recovery_codes'])]
class User extends Authenticatable implements FilamentUser, HasAppAuthentication, HasAppAuthenticationRecovery, HasName
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
            // Critical-class secrets (docs/06 §5) — encrypted at rest, never
            // selected by a mobile-facing API Resource.
            'app_authentication_secret' => 'encrypted',
            'app_authentication_recovery_codes' => 'encrypted:array',
        ];
    }

    public function isSubscriber(): bool
    {
        // Stubbed until the subscriptions feature (Phase 2) lands — spec §16/§17.
        // Never hardcode true here; premium-gated endpoints must fail closed.
        return false;
    }

    public function isAdmin(): bool
    {
        return $this->role === UserRole::Admin;
    }

    public function isModerator(): bool
    {
        return $this->role === UserRole::Moderator;
    }

    /**
     * docs/06-security-architecture.md §3.3: admin login is a separate
     * authenticated surface from the mobile Sanctum flow — only `admin`/
     * `moderator` accounts may reach the Filament panel at all. A plain
     * `user` account (e.g. a stolen session cookie) is refused before it can
     * see anything, same default-deny posture as every API policy here.
     */
    public function canAccessPanel(Panel $panel): bool
    {
        return in_array($this->role, [UserRole::Admin, UserRole::Moderator], true);
    }

    /**
     * `users` has no `name` column (docs/02) — Filament's HasName contract
     * needs one anyway, to label the panel's own account menu. Admin/
     * moderator accounts are provisioned by email, so that's the sane
     * default; falls back further only for the unusual case of a plain
     * `user` row being inspected through this same model class.
     */
    public function getFilamentName(): string
    {
        return $this->email ?? $this->phone ?? "User #{$this->id}";
    }

    /**
     * Filament's built-in TOTP app-authentication (docs/06 §3.3 "mandatory
     * 2FA (TOTP)") — these four methods plus the two below are exactly what
     * its HasAppAuthentication/HasAppAuthenticationRecovery contracts need
     * from the user model. Nothing here is reachable from the mobile API;
     * this is admin-panel-only surface.
     */
    public function getAppAuthenticationSecret(): ?string
    {
        return $this->app_authentication_secret;
    }

    public function saveAppAuthenticationSecret(#[SensitiveParameter] ?string $secret): void
    {
        $this->forceFill(['app_authentication_secret' => $secret])->save();
    }

    public function getAppAuthenticationHolderName(): string
    {
        return $this->email ?? $this->phone ?? "user#{$this->id}";
    }

    /**
     * @return array<string>|null
     */
    public function getAppAuthenticationRecoveryCodes(): ?array
    {
        return $this->app_authentication_recovery_codes;
    }

    /**
     * @param  array<string>|null  $codes
     */
    public function saveAppAuthenticationRecoveryCodes(#[SensitiveParameter] ?array $codes): void
    {
        $this->forceFill(['app_authentication_recovery_codes' => $codes])->save();
    }

    public function profile(): HasOne
    {
        return $this->hasOne(Profile::class);
    }

    public function preferences(): HasOne
    {
        return $this->hasOne(UserPreference::class);
    }

    public function profilePrompts(): HasMany
    {
        return $this->hasMany(UserProfilePrompt::class);
    }

    public function interests(): BelongsToMany
    {
        return $this->belongsToMany(Interest::class, 'user_interests')->withTimestamps();
    }

    public function location(): HasOne
    {
        return $this->hasOne(UserLocation::class);
    }

    public function swipesMade(): HasMany
    {
        return $this->hasMany(Swipe::class, 'actor_id');
    }

    public function blocksMade(): HasMany
    {
        return $this->hasMany(Block::class, 'blocker_id');
    }

    public function blockedBy(): HasMany
    {
        return $this->hasMany(Block::class, 'blocked_id');
    }

    /**
     * Added for the admin reports queue / user-detail view (Phase 1 item
     * 11) — nothing before this feature needed these from the `User` side.
     */
    public function reportsMade(): HasMany
    {
        return $this->hasMany(Report::class, 'reporter_id');
    }

    public function reportsReceived(): HasMany
    {
        return $this->hasMany(Report::class, 'reported_id');
    }

    public function devices(): HasMany
    {
        return $this->hasMany(UserDevice::class);
    }

    /**
     * Named `appNotifications`, not `notifications` — `Notifiable` (used
     * above for password-reset mail) already defines a `notifications()`
     * relation targeting Laravel's own default `notifications` table shape
     * (`notifiable_type`/`notifiable_id`/`data`), which is never actually
     * migrated in this app. Reusing that method name would silently shadow
     * it with a differently-shaped query; a distinct name avoids the clash
     * entirely rather than relying on nobody ever calling the built-in one.
     */
    public function appNotifications(): HasMany
    {
        return $this->hasMany(Notification::class);
    }
}
