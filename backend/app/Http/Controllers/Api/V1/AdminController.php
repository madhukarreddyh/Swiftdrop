<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\FareSetting;
use App\Models\Order;
use App\Models\Payout;
use App\Models\User;
use App\Models\Zone;
use Illuminate\Http\Request;

class AdminController extends Controller
{
    /**
     * GET /api/v1/admin/orders?status=
     */
    public function orders(Request $request)
    {
        $query = Order::with(['customer:id,name,phone', 'rider:id,name,phone'])->latest();

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json($query->paginate(25));
    }

    /**
     * POST /api/v1/admin/riders/{id}/verify  {approved: bool}
     */
    public function verifyRider(Request $request, User $id)
    {
        $data = $request->validate(['approved' => ['required', 'boolean']]);

        if (!$id->isRider()) {
            return response()->json(['message' => 'User is not a rider.'], 422);
        }

        $profile = $id->riderProfile()->firstOrCreate(['user_id' => $id->id]);
        $profile->update([
            'verification_status' => $data['approved'] ? 'approved' : 'rejected',
        ]);

        return response()->json($profile->fresh());
    }

    /**
     * GET /api/v1/admin/riders?status=
     */
    public function riders(Request $request)
    {
        $query = User::where('role', 'rider')->with('riderProfile')->latest();

        if ($request->filled('status')) {
            $query->whereHas('riderProfile', fn ($q) => $q->where('verification_status', $request->string('status')));
        }

        return response()->json($query->paginate(25));
    }

    /**
     * GET /api/v1/admin/fare-settings
     */
    public function fareSettings()
    {
        $settings = [];
        foreach (FareSetting::DEFAULTS as $key => $default) {
            $settings[$key] = FareSetting::get($key);
        }

        return response()->json($settings);
    }

    /**
     * PUT /api/v1/admin/fare-settings  {key: value, ...}
     * Changes apply instantly — no app update needed.
     */
    public function updateFareSettings(Request $request)
    {
        $allowed = array_keys(FareSetting::DEFAULTS);
        $data = $request->validate(
            collect($allowed)->mapWithKeys(fn ($k) => [$k => ['sometimes', 'string', 'max:50']])->all()
        );

        foreach ($data as $key => $value) {
            FareSetting::set($key, $value);
        }

        return response()->json(['message' => 'Fare settings updated.', 'settings' => $data]);
    }

    /**
     * GET /api/v1/admin/zones
     */
    public function zones()
    {
        return response()->json(Zone::orderBy('name')->get());
    }

    /**
     * POST /api/v1/admin/zones  {name, polygon: [[lat,lng],...], is_active}
     */
    public function createZone(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'polygon' => ['required', 'array', 'min:3'],
            'polygon.*' => ['array', 'size:2'],
            'polygon.*.*' => ['numeric'],
            'is_active' => ['boolean'],
        ]);

        $zone = Zone::create($data);

        return response()->json($zone, 201);
    }

    /**
     * PUT /api/v1/admin/zones/{zone}
     */
    public function updateZone(Request $request, Zone $zone)
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:100'],
            'polygon' => ['sometimes', 'array', 'min:3'],
            'polygon.*' => ['array', 'size:2'],
            'polygon.*.*' => ['numeric'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $zone->update($data);

        return response()->json($zone->fresh());
    }

    /**
     * POST /api/v1/admin/payouts/generate  {period_start, period_end}
     * Creates one payout row per rider with delivered trips in the period.
     */
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

        return response()->json(['message' => "Payouts generated for {$created} riders."]);
    }

    /**
     * GET /api/v1/admin/payouts?status=
     */
    public function payouts(Request $request)
    {
        $query = Payout::with('rider:id,name,phone')->latest();
        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json($query->paginate(25));
    }
}
