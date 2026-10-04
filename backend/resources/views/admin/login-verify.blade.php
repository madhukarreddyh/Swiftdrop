<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enter OTP — SwiftDrop</title>
    <style>
        :root { --green: #00B368; --green-dark: #009658; --ink: #1a1a1a; --muted: #6b7280; --line: #e5e7eb; }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; color: var(--ink); background: #f7f8f7; }
        .login-wrap { max-width: 400px; margin: 90px auto; padding: 0 16px; }
        .brand { font-size: 28px; font-weight: 800; text-align: center; margin-bottom: 20px; }
        .brand span { color: var(--green); }
        .login-card { background: #fff; border: 1px solid var(--line); border-radius: 16px; padding: 32px; }
        .login-card h2 { margin-bottom: 8px; }
        .login-card p { color: var(--muted); font-size: 14px; margin-bottom: 20px; }
        .field { margin-bottom: 14px; }
        .field label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 6px; }
        .field input { width: 100%; padding: 10px 12px; border: 1px solid var(--line); border-radius: 8px; font-size: 20px; letter-spacing: 6px; text-align: center; }
        .btn { display: inline-block; width: 100%; background: var(--green); color: #fff; border: 0; border-radius: 8px; padding: 11px; font-size: 15px; cursor: pointer; font-weight: 600; }
        .btn:hover { background: var(--green-dark); }
        .errors { background: #fee2e2; border: 1px solid #fca5a5; color: #991b1b; padding: 12px 16px; border-radius: 8px; margin-bottom: 16px; font-size: 14px; }
        .dev-code { background: #fffbeb; border: 1px dashed #d97706; padding: 12px; border-radius: 8px; font-size: 14px; margin-bottom: 16px; }
        .back { display: block; text-align: center; margin-top: 14px; font-size: 14px; color: var(--muted); }
    </style>
</head>
<body>
<div class="login-wrap">
    <div class="brand">Swift<span>Drop</span></div>
    <div class="login-card">
        <h2>Enter OTP</h2>
        <p>Code sent to +91 {{ session('admin_login_phone') }}.</p>

        @if (session('dev_code'))
            <div class="dev-code">Test mode — your code is <strong>{{ session('dev_code') }}</strong></div>
        @endif

        @if ($errors->any())
            <div class="errors">
                @foreach ($errors->all() as $e)
                    <div>{{ $e }}</div>
                @endforeach
            </div>
        @endif

        <form method="POST" action="{{ route('admin.login.verify.post') }}">
            @csrf
            <div class="field">
                <label for="code">4-digit code</label>
                <input id="code" name="code" type="text" inputmode="numeric" maxlength="4"
                       placeholder="••••" required autofocus autocomplete="one-time-code">
            </div>
            <button class="btn" type="submit">Verify &amp; log in</button>
        </form>
        <a class="back" href="{{ route('admin.login') }}">Use a different number</a>
    </div>
</div>
</body>
</html>
