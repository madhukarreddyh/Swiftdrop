<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'Admin') — SwiftDrop</title>
    <style>
        :root { --green: #00B368; --green-dark: #009658; --ink: #1a1a1a; --muted: #6b7280; --line: #e5e7eb; --bg: #f7f8f7; }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; color: var(--ink); background: var(--bg); }
        .shell { display: flex; min-height: 100vh; }
        .side { width: 220px; background: #fff; border-right: 1px solid var(--line); padding: 20px 12px; position: sticky; top: 0; height: 100vh; }
        .brand { font-size: 22px; font-weight: 800; padding: 4px 12px 18px; }
        .brand span { color: var(--green); }
        .nav a { display: block; padding: 10px 12px; border-radius: 8px; color: var(--ink); text-decoration: none; font-size: 14px; margin-bottom: 2px; }
        .nav a:hover { background: #f0faf4; }
        .nav a.active { background: var(--green); color: #fff; font-weight: 600; }
        .main { flex: 1; padding: 28px 32px; max-width: 1100px; }
        .topbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
        .topbar h1 { font-size: 24px; }
        .btn { display: inline-block; background: var(--green); color: #fff; border: 0; border-radius: 8px; padding: 9px 18px; font-size: 14px; cursor: pointer; text-decoration: none; font-weight: 600; }
        .btn:hover { background: var(--green-dark); }
        .btn.ghost { background: #fff; color: var(--ink); border: 1px solid var(--line); }
        .btn.danger { background: #dc2626; }
        .btn.small { padding: 6px 12px; font-size: 12px; }
        .card { background: #fff; border: 1px solid var(--line); border-radius: 12px; padding: 20px; margin-bottom: 20px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; margin-bottom: 20px; }
        .stat { background: #fff; border: 1px solid var(--line); border-radius: 12px; padding: 18px; }
        .stat .num { font-size: 30px; font-weight: 800; }
        .stat .lbl { color: var(--muted); font-size: 13px; margin-top: 4px; }
        table { width: 100%; border-collapse: collapse; font-size: 14px; }
        th { text-align: left; color: var(--muted); font-weight: 600; font-size: 12px; text-transform: uppercase; padding: 10px 12px; border-bottom: 1px solid var(--line); }
        td { padding: 12px; border-bottom: 1px solid var(--line); }
        tr:last-child td { border-bottom: 0; }
        .pill { display: inline-block; padding: 3px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; }
        .pill.green { background: #dcfce7; color: #166534; }
        .pill.amber { background: #fef3c7; color: #92400e; }
        .pill.red { background: #fee2e2; color: #991b1b; }
        .pill.gray { background: #f3f4f6; color: #4b5563; }
        .pill.blue { background: #dbeafe; color: #1e40af; }
        .flash { background: #dcfce7; border: 1px solid #86efac; color: #166534; padding: 12px 16px; border-radius: 8px; margin-bottom: 20px; font-size: 14px; }
        .errors { background: #fee2e2; border: 1px solid #fca5a5; color: #991b1b; padding: 12px 16px; border-radius: 8px; margin-bottom: 20px; font-size: 14px; }
        .field { margin-bottom: 14px; }
        .field label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 6px; }
        .field input, .field select { width: 100%; max-width: 420px; padding: 10px 12px; border: 1px solid var(--line); border-radius: 8px; font-size: 14px; }
        .field .hint { color: var(--muted); font-size: 12px; margin-top: 4px; }
        .kv { display: grid; grid-template-columns: 180px 1fr; gap: 8px 16px; font-size: 14px; }
        .kv dt { color: var(--muted); }
        .inline-form { display: inline; }
        .filterbar { display: flex; gap: 10px; margin-bottom: 16px; align-items: center; flex-wrap: wrap; }
        .filterbar select { padding: 8px 12px; border: 1px solid var(--line); border-radius: 8px; font-size: 14px; }
        .pagination { margin-top: 16px; font-size: 14px; }
        .login-wrap { max-width: 400px; margin: 80px auto; }
        .login-card { background: #fff; border: 1px solid var(--line); border-radius: 16px; padding: 32px; }
        .login-card h2 { margin-bottom: 8px; }
        .login-card p { color: var(--muted); font-size: 14px; margin-bottom: 20px; }
        .dev-code { background: #fffbeb; border: 1px dashed #d97706; padding: 12px; border-radius: 8px; font-size: 14px; margin-bottom: 16px; }
    </style>
</head>
<body>
<div class="shell">
    <aside class="side">
        <div class="brand">Swift<span>Drop</span></div>
        <nav class="nav">
            <a href="{{ route('admin.dashboard') }}" class="{{ request()->routeIs('admin.dashboard') ? 'active' : '' }}">Dashboard</a>
            <a href="{{ route('admin.riders') }}" class="{{ request()->routeIs('admin.riders*') ? 'active' : '' }}">Riders</a>
            <a href="{{ route('admin.orders') }}" class="{{ request()->routeIs('admin.orders*') ? 'active' : '' }}">Orders</a>
            <a href="{{ route('admin.zones') }}" class="{{ request()->routeIs('admin.zones*') ? 'active' : '' }}">Zones</a>
            <a href="{{ route('admin.fare') }}" class="{{ request()->routeIs('admin.fare*') ? 'active' : '' }}">Fare settings</a>
            <a href="{{ route('admin.payouts') }}" class="{{ request()->routeIs('admin.payouts*') ? 'active' : '' }}">Payouts</a>
        </nav>
    </aside>
    <div class="main">
        <div class="topbar">
            <h1>@yield('title', 'Admin')</h1>
            <form method="POST" action="{{ route('admin.logout') }}">
                @csrf
                <button class="btn ghost small" type="submit">Log out</button>
            </form>
        </div>

        @if (session('status'))
            <div class="flash">{{ session('status') }}</div>
        @endif
        @if ($errors->any())
            <div class="errors">
                @foreach ($errors->all() as $e)
                    <div>{{ $e }}</div>
                @endforeach
            </div>
        @endif

        @yield('content')
    </div>
</div>
</body>
</html>
