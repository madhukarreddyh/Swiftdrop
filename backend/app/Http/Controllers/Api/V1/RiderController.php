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

    /**
     * POST /api/v1/rider/apply
     * Partner application: any authenticated user submits KYC details,
     * which flips the account to role=rider with verification pending.
     * An admin then approves via POST /admin/riders/{id}/verify.
     * (Additive v1 endpoint for the rider app's onboarding flow.)
     */
    public function apply(Request $request)
    {
        $user = $request->user();

        $profile = RiderProfile::firstOrCreate(['user_id' => $user->id]);
        if ($profile->verification_status === 'approved') {
            return response()->json([
                'message' => 'You are already a verified partner.',
                'code' => 'ALREADY_VERIFIED',
            ], 422);
        }

        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'aadhaar' => ['required', 'string', 'max:20'],
            'licence_no' => ['required', 'string', 'max:30'],
            'bike_rc' => ['required', 'string', 'max:30'],
            'bike_number' => ['required', 'string', 'max:20'],
            'vehicle_type' => ['required', 'in:bike,auto'],
            'bank_account' => ['required', 'string', 'max:34'],
        ]);

        $user->update(['name' => $data['name'], 'role' => 'rider']);
        $profile->update([
            'aadhaar' => $data['aadhaar'],
            'licence_no' => $data['licence_no'],
            'bike_rc' => $data['bike_rc'],
            'bike_number' => $data['bike_number'],
            'vehicle_type' => $data['vehicle_type'],
            'bank_account' => $data['bank_account'],
            'verification_status' => 'pending',
        ]);

        return response()->json([
            'user' => $user->fresh()->only(['id', 'name', 'phone', 'role']),
            'profile' => $profile->fresh(),
        ]);
    }

    /**
     * GET /api/v1/rider/offers
     * Pending order offers for this rider (status=requested, rider is a
     * candidate, assignment not expired). Polled by the rider app every 15s
     * in v1 (FCM push not wired yet).
     * (Additive v1 endpoint for the rider app's incoming-order card.)
     */
    public function offers(Request $request)
    {
        $riderId = $request->user()->id;

        $offers = Order::where('status', Order::STATUS_REQUESTED)
            ->whereNotNull('assignment_expires_at')
            ->where('assignment_expires_at', '>', now())
            ->whereJsonContains('candidate_rider_ids', $riderId)
            ->latest()
            ->get();

        return response()->json(['offers' => $offers]);
    }

    private function profile(Request $request): RiderProfile
    {
        return RiderProfile::firstOrCreate(['user_id' => $request->user()->id]);
    }
}
