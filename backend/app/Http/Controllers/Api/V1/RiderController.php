<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\RiderProfile;
use Illuminate\Http\Request;

class RiderController extends Controller
{
    /**
     * POST /api/v1/rider/online  {is_online, lat, lng}
     */
    public function setOnline(Request $request)
    {
        $data = $request->validate([
            'is_online' => ['required', 'boolean'],
            'lat' => ['required_if:is_online,true', 'numeric', 'between:-90,90'],
            'lng' => ['required_if:is_online,true', 'numeric', 'between:-180,180'],
        ]);

        $profile = $this->profile($request);

        $profile->update([
            'is_online' => $data['is_online'],
            'last_lat' => $data['lat'] ?? $profile->last_lat,
            'last_lng' => $data['lng'] ?? $profile->last_lng,
            'last_seen_at' => now(),
        ]);

        return response()->json($profile->fresh());
    }

    /**
     * POST /api/v1/rider/location  {lat, lng}  (throttled)
     */
    public function updateLocation(Request $request)
    {
        $data = $request->validate([
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $this->profile($request)->update([
            'last_lat' => $data['lat'],
            'last_lng' => $data['lng'],
            'last_seen_at' => now(),
        ]);

        return response()->json(['message' => 'Location updated.']);
    }

    /**
     * POST /api/v1/rider/documents
     * Submit KYC documents for verification.
     */
    public function submitDocuments(Request $request)
    {
        $data = $request->validate([
            'aadhaar' => ['nullable', 'string', 'max:20'],
            'licence_no' => ['nullable', 'string', 'max:30'],
            'bike_rc' => ['nullable', 'string', 'max:30'],
            'bike_number' => ['nullable', 'string', 'max:20'],
            'bank_account' => ['nullable', 'string', 'max:34'],
        ]);

        $profile = $this->profile($request);
        $profile->update(array_merge($data, ['verification_status' => 'pending']));

        return response()->json($profile->fresh());
    }

    /**
     * GET /api/v1/rider/earnings
     */
    public function earnings(Request $request)
    {
        $userId = $request->user()->id;

        $base = Order::where('rider_id', $userId)
            ->where('status', Order::STATUS_DELIVERED);

        $today = (clone $base)->whereDate('delivered_at', today())->sum('rider_earning_paise');
        $week = (clone $base)->where('delivered_at', '>=', now()->startOfWeek())->sum('rider_earning_paise');
        $total = (clone $base)->sum('rider_earning_paise');
        $trips = (clone $base)->count();

        $recent = (clone $base)->latest('delivered_at')->limit(20)->get([
            'id', 'pickup_address', 'drop_address', 'distance_km',
            'fare_paise', 'rider_earning_paise', 'delivered_at',
        ]);

        return response()->json([
            'today_paise' => (int) $today,
            'week_paise' => (int) $week,
            'total_paise' => (int) $total,
            'total_trips' => $trips,
            'recent_trips' => $recent,
        ]);
    }

    /**
     * GET /api/v1/rider/orders — orders assigned to this rider.
     */
    public function orders(Request $request)
    {
        $orders = Order::where('rider_id', $request->user()->id)
            ->latest()
            ->paginate(20);

        return response()->json($orders);
    }

    /**
     * GET /api/v1/rider/profile
     */
    public function profile_show(Request $request)
    {
        return response()->json($this->profile($request));
    }

    private function profile(Request $request): RiderProfile
    {
        return RiderProfile::firstOrCreate(['user_id' => $request->user()->id]);
    }
}
