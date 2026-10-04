<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Web (Blade) guard for the admin panel.
 * The JSON API uses the 'role' middleware; this one redirects guests to the
 * admin login page and 403s signed-in non-admins.
 */
class EnsureAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user) {
            return redirect()->route('admin.login');
        }

        if ($user->role !== 'admin') {
            abort(403, 'Admins only.');
        }

        return $next($request);
    }
}
