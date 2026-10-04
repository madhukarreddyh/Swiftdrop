<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\FareSetting;
use App\Models\Order;
use App\Models\Payout;
use App\Models\RiderProfile;
use App\Models\User;
use App\Models\Zone;
use Illuminate\Http\Request;

/**
 * Blade admin panel. All routes sit behind the 'admin' (EnsureAdmin) middleware.
 * Mirrors the JSON admin API in app/Http/Controllers/Api/V1/AdminController.php.
 */
class AdminController extends Controller
{
    public function dashboard()
    {
        $today = now()->toDateString();

        return view('admin.dashboard', [
            'ordersToday' => Order::whereDate('created_at', $today)->count(),
            'onlineRiders' => RiderProfile::where('is_online', true)->count(),
            'platformEarningsToday' => (int) Order::where('status', Order::STATUS_DELIVERED)
                ->whereDate('delivered_at', $today)
                ->sum('platform_fee_paise'),
            'pendingApprovals' => RiderProfile::where('verification_status', 'pending')->count(),
            'pendingPayouts' => Payout::where('status', 'pending')->count(),
            'recentOrders' => Order::with(['customer:id,name,phone', 'rider:id,name,phone'])
                ->latest()->limit(10)->get(),
        ]);
    }

    // ---- Riders -----------------------------------------------------------

    public function riders(Request $request)
    {
        $query = User::where('role', 'rider')->with('riderProfile')->latest();

        if ($request->filled('status')) {
            $status = $request->string('status')->toString();
            $query->whereHas('riderProfile', fn ($q) => $q->where('verification_status', $status));
        }

        return view('admin.riders.index', [
            'riders' => $query->paginate(20)->withQueryString(),
            'status' => $request->string('status')->toString(),
        ]);
    }

    public function riderShow(User $rider)
    {
        abort_unless($rider->role === 'rider', 404);

        return view('admin.riders.show', [
            'rider' => $rider->load('riderProfile'),
            'orders' => Order::where('rider_id', $rider->id)->latest()->limit(20)->get(),
        ]);
    }

    public function verifyRider(Request $request, User $rider)
    {
        abort_unless($rider->role === 'rider', 404);

        $data = $request->validate(['approved' => ['required', 'boolean']]);

        $profile = $rider->riderProfile()->firstOrCreate(['user_id' => $rider->id]);
        $profile->update([
            'verification_status' => $data['approved'] ? 'approved' : 'rejected',
        ]);

        return redirect()->route('admin.riders.show', $rider)
            ->with('status', $data['approved'] ? 'Rider approved.' : 'Rider rejected.');
    }

    // ---- Orders -----------------------------------------------------------

    public function orders(Request $request)
    {
        $query = Order::with(['customer:id,name,phone', 'rider:id,name,phone'])->latest();

        if ($request->filled('status')) {
            $query->where('status', $request->string('status')->toString());
        }

        return view('admin.orders.index', [
            'orders' => $query->paginate(20)->withQueryString(),
            'status' => $request->string('status')->toString(),
            'statuses' => [
                Order::STATUS_REQUESTED,
                Order::STATUS_ASSIGNED,
                Order::STATUS_PICKED_UP,
                Order::STATUS_DELIVERED,
                Order::STATUS_CANCELLED,
            ],
        ]);
    }

    public function orderShow(Order $order)
    {
        return view('admin.orders.show', [
            'order' => $order->load(['customer:id,name,phone', 'rider:id,name,phone']),
        ]);
    }

    // ---- Zones ------------------------------------------------------------

    public function zones()
    {
        return view('admin.zones.index', [
            'zones' => Zone::orderBy('name')->get(),
        ]);
    }

    public function toggleZone(Zone $zone)
    {
        $zone->update(['is_active' => !$zone->is_active]);

        return redirect()->route('admin.zones')
            ->with('status', "Zone '{$zone->name}' is now " . ($zone->is_active ? 'active' : 'inactive') . '.');
    }

    // ---- Fare settings ----------------------------------------------------

    public function fare()
    {
        $settings = [];
        foreach (FareSetting::DEFAULTS as $key => $default) {
            $settings[$key] = FareSetting::get($key);
        }

        return view('admin.fare.index', ['settings' => $settings]);
    }

    public function updateFare(Request $request)
    {
        $allowed = array_keys(FareSetting::DEFAULTS);
        $data = $request->validate(
            collect($allowed)->mapWithKeys(fn ($k) => [$k => ['sometimes', 'string', 'max:50']])->all()
        );

        foreach ($data as $key => $value) {
            FareSetting::set($key, $value);
        }

        return redirect()->route('admin.fare')->with('status', 'Fare settings updated. Changes apply instantly.');
    }

    // ---- Payouts ----------------------------------------------------------

    public function payouts(Request $request)
    {
        $query = Payout::with('rider:id,name,phone')->latest();

        if ($request->filled('status')) {
            $query->where('status', $request->string('status')->toString());
        }

        return view('admin.payouts.index', [
            'payouts' => $query->paginate(20)->withQueryString(),
            'status' => $request->string('status')->toString(),
        ]);
    }

    public function generatePayouts(Request $request)
    {
        $data = $request->validate([
            'period_start' => ['required', 'date'],
            'period_end' => ['required', 'date', 'after_or_equal:period_start'],
        ]);

        $rows = Order::where('status', Order::STATUS_DELIVERED)
            ->whereNotNull('rider_id')
            ->whereBetween('delivered_at', [$data['period_start'] . ' 00:00:00', $data['period_end'] . ' 23:59:59'])
            ->selectRaw('rider_id, COUNT(*) as trips, SUM(rider_earning_paise) as amount')
            ->groupBy('rider_id')
            ->get();

        $created = 0;
        foreach ($rows as $row) {
            Payout::updateOrCreate(
                [
                    'rider_id' => $row->rider_id,
                    'period_start' => $data['period_start'],
                    'period_end' => $data['period_end'],
                ],
                ['trips' => $row->trips, 'amount_paise' => $row->amount]
            );
            $created++;
        }

        return redirect()->route('admin.payouts')
            ->with('status', "Payouts generated for {$created} rider(s).");
    }

    public function markPayoutPaid(Request $request, Payout $payout)
    {
        $data = $request->validate([
            'bank_ref' => ['nullable', 'string', 'max:100'],
        ]);

        $payout->update([
            'status' => 'paid',
            'bank_ref' => $data['bank_ref'] ?? $payout->bank_ref,
            'paid_at' => now(),
        ]);

        return redirect()->route('admin.payouts')
            ->with('status', 'Payout marked as paid.');
    }
}
