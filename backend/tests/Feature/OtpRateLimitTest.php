<?php

namespace Tests\Feature;

/**
 * OTP login: rate limiting (max 4 sends/hour/phone), verification,
 * wrong-code rejection, and expiry.
 */
class OtpRateLimitTest extends SwiftDropTestCase
{
    public function test_otp_send_is_rate_limited(): void
    {
        $phone = '9876543210';

        for ($i = 0; $i < 4; $i++) {
            $this->postJson('/api/v1/auth/otp/send', ['phone' => $phone], $this->jsonHeaders())
                ->assertOk();
        }

        // 5th send within the hour → 429.
        $this->postJson('/api/v1/auth/otp/send', ['phone' => $phone], $this->jsonHeaders())
            ->assertStatus(429)
            ->assertJsonStructure(['message', 'retry_after_seconds']);
    }

    public function test_otp_verify_with_correct_code_returns_token(): void
    {
        $phone = '9876543210';

        $send = $this->postJson('/api/v1/auth/otp/send', ['phone' => $phone], $this->jsonHeaders());
        $send->assertOk();
        $code = $send->json('dev_code'); // dev mode returns the code
        $this->assertMatchesRegularExpression('/^\d{4}$/', $code);

        $verify = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => $phone,
            'code' => $code,
        ], $this->jsonHeaders());

        $verify->assertOk()
            ->assertJsonStructure(['token', 'user' => ['id', 'name', 'phone', 'role']])
            ->assertJsonPath('user.phone', $phone)
            ->assertJsonPath('user.role', 'customer');

        $this->assertNotEmpty($verify->json('token'));
    }

    public function test_otp_verify_with_wrong_code_fails(): void
    {
        $phone = '9876543210';

        $this->postJson('/api/v1/auth/otp/send', ['phone' => $phone], $this->jsonHeaders())->assertOk();

        // Pick a code guaranteed different from the real one.
        $real = \App\Models\Otp::where('phone', $phone)->latest('id')->first()->code;
        $wrong = $real === '0000' ? '0001' : '0000';

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => $phone,
            'code' => $wrong,
        ], $this->jsonHeaders())
            ->assertStatus(422)
            ->assertJsonPath('code', 'INVALID');
    }

    public function test_expired_otp_is_rejected(): void
    {
        $phone = '9876543210';

        $send = $this->postJson('/api/v1/auth/otp/send', ['phone' => $phone], $this->jsonHeaders());
        $code = $send->json('dev_code');

        \App\Models\Otp::where('phone', $phone)->update(['expires_at' => now()->subMinute()]);

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => $phone,
            'code' => $code,
        ], $this->jsonHeaders())
            ->assertStatus(422)
            ->assertJsonPath('code', 'EXPIRED');
    }

    public function test_invalid_phone_format_rejected(): void
    {
        $this->postJson('/api/v1/auth/otp/send', ['phone' => '12345'], $this->jsonHeaders())
            ->assertStatus(422);
    }

    public function test_protected_route_requires_token(): void
    {
        $this->getJson('/api/v1/orders', $this->jsonHeaders())->assertUnauthorized();
    }
}
