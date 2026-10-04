<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\OtpService;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    /**
     * POST /api/v1/auth/otp/send  {phone}
     * Rate-limited: max 4 sends per phone per hour.
     */
    public function sendOtp(Request $request)
    {
        $data = $request->validate([
            'phone' => ['required', 'regex:/^[6-9]\d{9}$/'],
        ]);
        $phone = $data['phone'];

        if (!OtpService::canSend($phone)) {
            return response()->json([
                'message' => 'Too many OTP requests. Try again later.',
                'retry_after_seconds' => OtpService::secondsUntilRetry($phone),
            ], 429);
        }

        $code = OtpService::send($phone);

        $response = ['message' => 'OTP sent.'];

        // OTP test mode (OTP_DEBUG=true in .env): return the code so the app
        // can be tested without an SMS provider. Rate limiting above still
        // applies in test mode. NEVER enable in production — the code would
        // be exposed to anyone who requests it.
        if (config('otp.debug')) {
            $response['dev_code'] = $code;
        }

        return response()->json($response);
    }

    /**
     * POST /api/v1/auth/otp/verify  {phone, code}
     * Returns a Sanctum token. Auto-creates the customer account.
     */
    public function verifyOtp(Request $request)
    {
        $data = $request->validate([
            'phone' => ['required', 'regex:/^[6-9]\d{9}$/'],
            'code' => ['required', 'digits:4'],
        ]);

        $result = OtpService::verify($data['phone'], $data['code']);

        if (!$result['ok']) {
            $messages = [
                'NO_OTP' => 'No OTP found. Request a new one.',
                'EXPIRED' => 'OTP expired. Request a new one.',
                'TOO_MANY_ATTEMPTS' => 'Too many wrong attempts. Request a new OTP.',
                'INVALID' => 'Wrong OTP.',
            ];

            return response()->json([
                'message' => $messages[$result['error']] ?? 'Verification failed.',
                'code' => $result['error'],
            ], 422);
        }

        $user = User::firstOrCreate(
            ['phone' => $data['phone']],
            [
                'name' => 'SwiftDrop User',
                'role' => 'customer',
                // OTP-only login; password is a non-empty placeholder (never used).
                'password' => bcrypt(str()->random(32)),
            ]
        );

        // Riders/admins are created by onboarding, never auto-created here.
        $token = $user->createToken('swiftdrop-app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $user->only(['id', 'name', 'phone', 'role', 'avatar']),
        ]);
    }

    /**
     * POST /api/v1/auth/logout
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }
}
