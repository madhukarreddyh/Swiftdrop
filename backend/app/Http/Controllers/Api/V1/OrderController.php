<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Services\FareService;
use App\Services\MatchingService;
use App\Services\PaymentService;
use App\Services\ZoneService;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    /**
     * POST /api/v1/orders (auth: any role)
     * Creates the order with a SERVER-COMPUTED fare and dispatches matching.
     */
    public function store(Request $request)
    {
        $data = $request->validate([
            'pickup_address' => ['required', 'string', 'max:255'],
            'pickup_lat' => ['required', 'numeric', 'between:-90,90'],
            'pickup_lng' => ['required', 'numeric', 'between:-180,180'],
            'drop_address' => ['required', 'string', 'max:255'],
            'drop_lat' => ['required', 'numeric', 'between:-90,90'],
            'drop_lng' => ['required', 'numeric', 'between:-180,180'],
            'parcel_type' => ['nullable', 'string', 'max:50'],
            'parcel_photo' => ['nullable', 'image', 'max:5120'],
            'payment_mode' => ['nullable', 'in:upi,cash'],
        ]);

        if (!ZoneService::insideActiveZone($data['pickup_lat'], $data['pickup_lng'])
            || !ZoneService::insideActiveZone($data['drop_lat'], $data['drop_lng'])) {
            return response()->json([
                'message' => "We haven't reached this area yet.",
                'code' => 'OUT_OF_ZONE',
            ], 422);
        }

        // Fare is ALWAYS computed server-side. The client never sends a price.
        $quote = FareService::quote(
            $data['pickup_lat'], $data['pickup_lng'],
            $data['drop_lat'], $data['drop_lng']
        );

        $photoPath = null;
        if ($request->hasFile('parcel_photo')) {
            $photoPath = $request->file('parcel_photo')->store('parcels', 'public');
        }

        $order = Order::create([
            'customer_id' => $request->user()->id,
            'pickup_address' => $data['pickup_address'],
            'pickup_lat' => $data['pickup_lat'],
            'pickup_lng' => $data['pickup_lng'],
            'drop_address' => $data['drop_address'],
            'drop_lat' => $data['drop_lat'],
            'drop_lng' => $data['drop_lng'],
            'distance_km' => $quote['distance_km'],
            'fare_paise' => $quote['fare_paise'],
            'platform_fee_paise' => $quote['platform_fee_paise'],
            'rider_earning_paise' => $quote['rider_earning_paise'],
            'parcel_type' => $data['parcel_type'] ?? null,
            'parcel_photo_path' => $photoPath,
            'status' => Order::STATUS_REQUESTED,
            'pickup_otp' => (string) random_int(1000, 9999),
            'pickup_otp_expires_at' => now()->addMinutes(10),
            'payment_mode' => $data['payment_mode'] ?? 'upi',
        ]);

        MatchingService::dispatch($order);

        return response()->json($order->fresh(), 201);
    }

    /**
     * GET /api/v1/orders (auth)
     * Customers see their own; riders see assigned to them.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $query = Order::query()->latest();
        if ($user->isRider()) {
            $query->where('rider_id', $user->id);
        } elseif (!$user->isAdmin()) {
            $query->where('customer_id', $user->id);
        }

        return response()->json($query->paginate(20));
    }

    /**
     * GET /api/v1/orders/{id} (auth: owner, assigned rider, or admin)
     */
    public function show(Request $request, Order $order)
    {
        $this->authorizeView($request->user(), $order);

        return response()->json($order->load(['customer:id,name,phone', 'rider:id,name,phone']));
    }

    /**
     * POST /api/v1/orders/{id}/cancel (auth: customer, before pickup)
     */
    public function cancel(Request $request, Order $order)
    {
        $user = $request->user();

        if ($order->customer_id !== $user->id && !$user->isAdmin()) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }
        if (in_array($order->status, [Order::STATUS_PICKED_UP, Order::STATUS_DELIVERED, Order::STATUS_CANCELLED], true)) {
            return response()->json(['message' => 'Order can no longer be cancelled.', 'code' => 'TOO_LATE'], 422);
        }

        $order->update(['status' => Order::STATUS_CANCELLED]);

        return response()->json($order->fresh());
    }

    /**
     * POST /api/v1/orders/{id}/accept (auth: rider)
     * Atomic — exactly one rider wins.
     */
    public function accept(Request $request, Order $order)
    {
        $result = MatchingService::accept($order, $request->user());

        if (!$result['ok']) {
            $messages = [
                'ALREADY_TAKEN' => 'This order was already taken.',
                'ASSIGNMENT_EXPIRED' => 'Assignment expired. It will be re-offered.',
                'NOT_OFFERED' => 'This order was not offered to you.',
            ];

            return response()->json([
                'message' => $messages[$result['error']] ?? 'Could not accept.',
                'code' => $result['error'],
            ], 409);
        }

        return response()->json($order->fresh());
    }

    /**
     * POST /api/v1/orders/{id}/pickup  {otp} (auth: assigned rider)
     * Verifies the pickup OTP, generates the delivery OTP.
     */
    public function pickup(Request $request, Order $order)
    {
        $data = $request->validate(['otp' => ['required', 'digits:4']]);

        if ($order->rider_id !== $request->user()->id) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }
        if ($order->status !== Order::STATUS_ASSIGNED) {
            return response()->json(['message' => 'Order is not ready for pickup.', 'code' => 'BAD_STATE'], 422);
        }

        $check = $this->checkOtp($order->pickup_otp, $order->pickup_otp_expires_at, $data['otp']);
        if (!$check['ok']) {
            return response()->json(['message' => $check['message'], 'code' => $check['code']], 422);
        }

        $order->update([
            'status' => Order::STATUS_PICKED_UP,
            'picked_up_at' => now(),
            'delivery_otp' => (string) random_int(1000, 9999),
            'delivery_otp_expires_at' => now()->addMinutes(10),
        ]);

        return response()->json($order->fresh());
    }

    /**
     * POST /api/v1/orders/{id}/deliver  {otp} (auth: assigned rider)
     * Verifies the delivery OTP and completes the order.
     */
    public function deliver(Request $request, Order $order)
    {
        $data = $request->validate(['otp' => ['required', 'digits:4']]);

        if ($order->rider_id !== $request->user()->id) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }
        if ($order->status !== Order::STATUS_PICKED_UP) {
            return response()->json(['message' => 'Order is not out for delivery.', 'code' => 'BAD_STATE'], 422);
        }

        $check = $this->checkOtp($order->delivery_otp, $order->delivery_otp_expires_at, $data['otp']);
        if (!$check['ok']) {
            return response()->json(['message' => $check['message'], 'code' => $check['code']], 422);
        }

        $order->update([
            'status' => Order::STATUS_DELIVERED,
            'delivered_at' => now(),
        ]);

        // UPI: create the payment row so the app can open checkout.
        if ($order->payment_mode === 'upi') {
            PaymentService::initiate($order->fresh());
        }

        // Bump rider stats.
        $profile = $order->rider->riderProfile;
        if ($profile) {
            $profile->increment('total_trips');
        }

        return response()->json($order->fresh()->load('payment'));
    }

    /**
     * POST /api/v1/orders/{id}/otp/refresh (auth: customer)
     * Regenerates the currently-pending handover OTP (it expired or was lost).
     * Only the customer can do this — the OTP is their secret to share.
     */
    public function refreshOtp(Request $request, Order $order)
    {
        if ($order->customer_id !== $request->user()->id) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        if ($order->status === Order::STATUS_ASSIGNED) {
            $order->update([
                'pickup_otp' => (string) random_int(1000, 9999),
                'pickup_otp_expires_at' => now()->addMinutes(10),
            ]);
        } elseif ($order->status === Order::STATUS_PICKED_UP) {
            $order->update([
                'delivery_otp' => (string) random_int(1000, 9999),
                'delivery_otp_expires_at' => now()->addMinutes(10),
            ]);
        } else {
            return response()->json(['message' => 'No pending OTP for this order.', 'code' => 'BAD_STATE'], 422);
        }

        $response = ['message' => 'New OTP generated.'];
        if (config('app.debug')) {
            $response['dev_otp'] = $order->status === Order::STATUS_ASSIGNED
                ? $order->pickup_otp
                : $order->delivery_otp;
        }

        return response()->json($response);
    }

    private function authorizeView($user, Order $order): void
    {
        $allowed = $user->isAdmin()
            || $order->customer_id === $user->id
            || $order->rider_id === $user->id;

        abort_unless($allowed, 403, 'Forbidden.');
    }

    private function checkOtp(?string $expected, $expiresAt, string $given): array
    {
        if (!$expected || !$expiresAt || $expiresAt->isPast()) {
            return ['ok' => false, 'code' => 'OTP_EXPIRED', 'message' => 'OTP expired. Ask the customer to generate a new one.'];
        }
        if (!hash_equals($expected, $given)) {
            return ['ok' => false, 'code' => 'OTP_INVALID', 'message' => 'Wrong OTP.'];
        }

        return ['ok' => true];
    }
}
