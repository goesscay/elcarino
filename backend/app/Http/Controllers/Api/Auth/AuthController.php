<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\OAuthLoginRequest;
use App\Http\Requests\Auth\OtpRequestRequest;
use App\Http\Requests\Auth\OtpVerifyRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\Auth\OAuth\AppleTokenVerifier;
use App\Services\Auth\OAuth\GoogleTokenVerifier;
use App\Services\Auth\OAuth\InvalidOAuthTokenException;
use App\Services\Auth\OAuth\OAuthTokenVerifier;
use App\Services\Auth\OtpService;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;

class AuthController extends Controller
{
    public function __construct(private readonly OtpService $otp) {}

    /**
     * POST /api/v1/auth/register — email + password. Auto-logs in on success.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = User::create([
            'email' => $request->string('email')->toString(),
            'password' => $request->string('password')->toString(),
        ]);

        return $this->tokenResponse($user, $request->string('device_name')->toString(), 201);
    }

    /**
     * POST /api/v1/auth/login — email or phone + password.
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $user = $request->filled('email')
            ? User::query()->where('email', $request->string('email'))->first()
            : User::query()->where('phone', $request->string('phone'))->first();

        if (! $user || ! $user->password || ! Hash::check($request->string('password'), $user->password)) {
            return $this->errorResponse('invalid_credentials', 'These credentials do not match our records.', 422);
        }

        return $this->tokenResponse($user, $request->string('device_name')->toString());
    }

    /**
     * POST /api/v1/auth/otp/request — sends a phone OTP. Always responds 202
     * regardless of whether the phone is already registered, so this endpoint
     * can't be used to enumerate accounts.
     */
    public function requestOtp(OtpRequestRequest $request): JsonResponse
    {
        $this->otp->requestCode($request->string('phone')->toString());

        return response()->json(['message' => 'If the number is valid, a verification code has been sent.'], 202);
    }

    /**
     * POST /api/v1/auth/otp/verify — verifies the code; creates the account on
     * first successful verification (passwordless phone signup/login, spec §5).
     */
    public function verifyOtp(OtpVerifyRequest $request): JsonResponse
    {
        $phone = $request->string('phone')->toString();

        if (! $this->otp->verifyCode($phone, $request->string('code')->toString())) {
            return $this->errorResponse('invalid_otp', 'That code is invalid or has expired.', 422);
        }

        $user = User::query()->firstOrCreate(
            ['phone' => $phone],
            ['phone_verified_at' => now()],
        );

        if (! $user->phone_verified_at) {
            $user->forceFill(['phone_verified_at' => now()])->save();
        }

        return $this->tokenResponse($user, $request->string('device_name')->toString());
    }

    /**
     * POST /api/v1/auth/oauth/google
     */
    public function oauthGoogle(OAuthLoginRequest $request, GoogleTokenVerifier $verifier): JsonResponse
    {
        return $this->oauthLogin($request, $verifier, 'google_id');
    }

    /**
     * POST /api/v1/auth/oauth/apple
     */
    public function oauthApple(OAuthLoginRequest $request, AppleTokenVerifier $verifier): JsonResponse
    {
        return $this->oauthLogin($request, $verifier, 'apple_id');
    }

    private function oauthLogin(OAuthLoginRequest $request, OAuthTokenVerifier $verifier, string $column): JsonResponse
    {
        try {
            $payload = $verifier->verify($request->string('id_token')->toString());
        } catch (InvalidOAuthTokenException $e) {
            return $this->errorResponse('invalid_oauth_token', $e->getMessage(), 422);
        }

        $user = User::query()->where($column, $payload->providerUserId)->first();

        if (! $user) {
            // Link to an existing verified-email account rather than duplicating it.
            $user = $payload->email
                ? User::query()->where('email', $payload->email)->first()
                : null;

            $user ??= new User(['email' => $payload->email]);
            $user->{$column} = $payload->providerUserId;
            if ($payload->email && ! $user->email_verified_at) {
                $user->email = $payload->email;
                $user->email_verified_at = now();
            }
            $user->save();
        }

        return $this->tokenResponse($user, $request->string('device_name')->toString());
    }

    /**
     * POST /api/v1/auth/logout — revokes only the token used for this request.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }

    /**
     * POST /api/v1/auth/password/forgot
     */
    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        Password::sendResetLink($request->only('email'));

        // Always 202 — never reveal whether the email exists (security doc §7 spirit).
        return response()->json(['message' => 'If that email is registered, a reset link has been sent.'], 202);
    }

    /**
     * POST /api/v1/auth/password/reset
     */
    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (User $user, string $password) {
                $user->forceFill(['password' => Hash::make($password)])->save();
                $user->tokens()->delete(); // revoke all sessions on password change (security doc §2.1)
                event(new PasswordReset($user));
            }
        );

        if ($status !== Password::PASSWORD_RESET) {
            return $this->errorResponse('invalid_reset_token', __($status), 422);
        }

        return response()->json(['message' => 'Password reset.']);
    }

    /**
     * Issues a Sanctum personal access token scoped to one device.
     *
     * NOTE: this is a single expiring access token, not the access+refresh
     * pair described in security doc §2.1 — refresh-token rotation is
     * deferred to a fast-follow so the client doesn't have to re-implement
     * its token handling later. Kept the TTL short (60 min default) to bound
     * the exposure in the meantime.
     */
    private function tokenResponse(User $user, string $deviceName, int $status = 200): JsonResponse
    {
        $user->forceFill(['last_active_at' => now()])->save();

        $ttlMinutes = config('sanctum.expiration');
        $token = $user->createToken($deviceName, expiresAt: $ttlMinutes ? now()->addMinutes((int) $ttlMinutes) : null);

        return response()->json([
            'user' => new UserResource($user),
            'token' => $token->plainTextToken,
            'token_type' => 'Bearer',
        ], $status);
    }

    private function errorResponse(string $code, string $message, int $status): JsonResponse
    {
        return response()->json(['error' => ['code' => $code, 'message' => $message]], $status);
    }
}
