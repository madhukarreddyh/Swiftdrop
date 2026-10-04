<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\OtpService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/**
 * Admin sign-in reuses the backend's OTP system — no separate password auth.
 * Only users with role=admin may sign in here.
 */
class AdminAuthController extends Controller
{
    public function showLogin()
    {
        if (Auth::check() && Auth::user()->role === 'admin') {
            return redirect()->route('admin.dashboard');
        }

        return view('admin.login');
    }

    public function sendOtp(Request $request)
    {
        $data = $request->validate([
            'phone' => ['required', 'regex:/^[6-9]\d{9}$/'],
        ]);

        $user = User::where('phone', $data['phone'])->where('role', 'admin')->first();

        if (!$user) {
            return back()->withErrors(['phone' => 'No admin account found for this number.'])->withInput();
        }

        if (!OtpService::canSend($data['phone'])) {
            return back()->withErrors([
                'phone' => 'Too many OTP requests. Try again in ' . OtpService::secondsUntilRetry($data['phone']) . ' seconds.',
            ])->withInput();
        }

        $code = OtpService::send($data['phone']);

        session(['admin_login_phone' => $data['phone']]);

        // Test mode only: there is no SMS provider yet, so show the code on screen
        // (mirrors the API's dev_code behaviour when OTP_DEBUG=true).
        if (config('otp.debug')) {
            session()->flash('dev_code', $code);
        }

        return redirect()->route('admin.login.verify');
    }

    public function showVerify()
    {
        if (!session('admin_login_phone')) {
            return redirect()->route('admin.login');
        }

        return view('admin.login-verify');
    }

    public function verify(Request $request)
    {
        $phone = session('admin_login_phone');

        if (!$phone) {
            return redirect()->route('admin.login');
        }

        $data = $request->validate([
            'code' => ['required', 'digits:4'],
        ]);

        $result = OtpService::verify($phone, $data['code']);

        if (!$result['ok']) {
            return back()->withErrors(['code' => 'Wrong or expired code. Try again.']);
        }

        $user = User::where('phone', $phone)->where('role', 'admin')->first();

        if (!$user) {
            return redirect()->route('admin.login')->withErrors(['phone' => 'Admin account no longer exists.']);
        }

        Auth::login($user);
        $request->session()->regenerate();
        session()->forget('admin_login_phone');

        return redirect()->intended(route('admin.dashboard'));
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }
}
