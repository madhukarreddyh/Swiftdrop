<?php

namespace App\Services;

use App\Models\Otp;
use Illuminate\Support\Facades\RateLimiter;

/**
 * 4-digit OTPs for login. Rate-limited: max 4 sends per phone per hour.
 * The code is NEVER written to logs.
 */
class OtpService
{
    public const MAX_SENDS_PER_HOUR = 4;
    public const MAX_ATTEMPTS = 5;
    public const TTL_MINUTES = 10;

    public static function canSend(string $phone): bool
    {
        return !RateLimiter::tooManyAttempts("otp-send:{$phone}", self::MAX_SENDS_PER_HOUR);
    }

    public static function secondsUntilRetry(string $phone): int
    {
        return RateLimiter::availableIn("otp-send:{$phone}");
    }

    /**
     * Generate and store a login OTP. Returns the plain code so the
     * controller can include it in test-mode responses (OTP_DEBUG=true).
     * In production a real SMS driver sends it instead.
     */
    public static function send(string $phone, string $purpose = 'login'): string
    {
        RateLimiter::hit("otp-send:{$phone}", 3600);

        // Invalidate any previous unconsumed OTPs for this phone+purpose.
        Otp::where('phone', $phone)
            ->where('purpose', $purpose)
            ->whereNull('consumed_at')
            ->update(['consumed_at' => now()]);

        $code = (string) random_int(1000, 9999);

        Otp::create([
            'phone' => $phone,
            'code' => $code,
            'purpose' => $purpose,
            'expires_at' => now()->addMinutes(self::TTL_MINUTES),
        ]);

        // TODO: plug a real SMS driver here (MSG91 / Twilio / Firebase).
        // Never log $code.

        return $code;
    }

    /**
     * @return array{ok: bool, error?: string, otp?: Otp}
     */
    public static function verify(string $phone, string $code, string $purpose = 'login'): array
    {
        $otp = Otp::where('phone', $phone)
            ->where('purpose', $purpose)
            ->whereNull('consumed_at')
            ->latest('id')
            ->first();

        if (!$otp) {
            return ['ok' => false, 'error' => 'NO_OTP'];
        }
        if ($otp->isExpired()) {
            return ['ok' => false, 'error' => 'EXPIRED'];
        }
        if ($otp->attempts >= self::MAX_ATTEMPTS) {
            return ['ok' => false, 'error' => 'TOO_MANY_ATTEMPTS'];
        }

        $otp->increment('attempts');

        if (!hash_equals($otp->code, $code)) {
            return ['ok' => false, 'error' => 'INVALID'];
        }

        $otp->update(['consumed_at' => now()]);

        return ['ok' => true, 'otp' => $otp->fresh()];
    }
}
