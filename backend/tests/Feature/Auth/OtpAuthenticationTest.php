<?php

namespace Tests\Feature\Auth;

use App\Models\OtpCode;
use App\Models\User;
use App\Services\Sms\SmsSender;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class OtpAuthenticationTest extends TestCase
{
    use RefreshDatabase;

    private const PHONE = '+60123456789';

    public function test_requesting_and_verifying_a_code_creates_and_authenticates_a_new_user(): void
    {
        $sender = $this->fakeSmsSender();

        $this->postJson('/api/v1/auth/otp/request', ['phone' => self::PHONE])->assertStatus(202);

        $code = $this->extractCode($sender->lastMessage);

        $response = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => $code,
            'device_name' => 'pixel-9',
        ]);

        $response->assertOk()->assertJsonStructure(['user' => ['id', 'phone'], 'token', 'token_type']);
        $this->assertDatabaseHas('users', ['phone' => self::PHONE]);
        $this->assertNotNull(
            User::query()->where('phone', self::PHONE)->firstOrFail()->phone_verified_at
        );
    }

    public function test_verifying_an_existing_users_phone_logs_them_in_without_duplicating_the_account(): void
    {
        $user = User::factory()->withPhone(self::PHONE)->create();
        $sender = $this->fakeSmsSender();

        $this->postJson('/api/v1/auth/otp/request', ['phone' => self::PHONE]);
        $code = $this->extractCode($sender->lastMessage);

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => $code,
            'device_name' => 'pixel-9',
        ])->assertOk();

        $this->assertSame(1, User::query()->where('phone', self::PHONE)->count());
        $this->assertSame($user->id, User::query()->where('phone', self::PHONE)->firstOrFail()->id);
    }

    public function test_verification_fails_with_the_wrong_code(): void
    {
        $this->fakeSmsSender();
        $this->postJson('/api/v1/auth/otp/request', ['phone' => self::PHONE]);

        $response = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => '000000',
            'device_name' => 'pixel-9',
        ]);

        $response->assertStatus(422)->assertJsonPath('error.code', 'invalid_otp');
        $this->assertDatabaseMissing('users', ['phone' => self::PHONE]);
    }

    public function test_verification_fails_once_the_code_has_expired(): void
    {
        $sender = $this->fakeSmsSender();
        $this->postJson('/api/v1/auth/otp/request', ['phone' => self::PHONE]);
        $code = $this->extractCode($sender->lastMessage);

        OtpCode::query()->where('phone', self::PHONE)->update(['expires_at' => now()->subMinute()]);

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => self::PHONE,
            'code' => $code,
            'device_name' => 'pixel-9',
        ])->assertStatus(422)->assertJsonPath('error.code', 'invalid_otp');
    }

    public function test_a_code_cannot_be_reused(): void
    {
        $sender = $this->fakeSmsSender();
        $this->postJson('/api/v1/auth/otp/request', ['phone' => self::PHONE]);
        $code = $this->extractCode($sender->lastMessage);

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => self::PHONE, 'code' => $code, 'device_name' => 'pixel-9',
        ])->assertOk();

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => self::PHONE, 'code' => $code, 'device_name' => 'pixel-9',
        ])->assertStatus(422)->assertJsonPath('error.code', 'invalid_otp');
    }

    private function fakeSmsSender(): object
    {
        $sender = new class implements SmsSender
        {
            public string $lastMessage = '';

            public function send(string $phone, string $message): void
            {
                $this->lastMessage = $message;
            }
        };

        $this->app->instance(SmsSender::class, $sender);

        return $sender;
    }

    private function extractCode(string $message): string
    {
        preg_match('/\d{6}/', $message, $matches);

        $this->assertNotEmpty($matches, 'Expected the SMS message to contain a 6-digit code.');

        return $matches[0];
    }
}
