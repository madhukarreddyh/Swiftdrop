<?php

namespace Tests\Feature;

use App\Models\Order;

/**
 * Full order lifecycle: requested → assigned → picked_up → delivered,
 * with pickup and delivery OTP verification.
 */
class OrderLifecycleTest extends SwiftDropTestCase
{
    public function test_full_lifecycle_with_otps(): void
    {
        $customer = $this->makeCustomer('9876543210');
        $rider = $this->makeRider('9876543211', approved: true, online: true);

        // 1. Customer creates an order (~5 km inside Kukatpally).
        $create = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'KPHB Colony, Road 5',
            'pickup_lat' => 17.4833,
            'pickup_lng' => 78.4100,
            'drop_address' => 'Kukatpally Metro',
            'drop_lat' => 17.5282, // ~4.99 km north
            'drop_lng' => 78.4100,
            'parcel_type' => 'Documents',
            'payment_mode' => 'upi',
            // A malicious client trying to set its own price — must be ignored.
            'fare_paise' => 100,
        ], $this->authHeaders($customer));

        $create->assertCreated();
        $orderId = $create->json('id');

        /** @var Order $order */
        $order = Order::findOrFail($orderId);
        $this->assertEquals(Order::STATUS_REQUESTED, $order->status);
        $this->assertEquals(5000, $order->fare_paise); // server-computed, not 100
        $this->assertEquals(250, $order->platform_fee_paise);
        $this->assertEquals(4750, $order->rider_earning_paise);
        $this->assertContains($rider->id, $order->candidate_rider_ids);

        // OTPs must NEVER leak through the API.
        $this->assertArrayNotHasKey('pickup_otp', $create->json());
        $this->assertArrayNotHasKey('delivery_otp', $create->json());

        // 2. Rider accepts.
        $accept = $this->postJson(
            "/api/v1/orders/{$orderId}/accept",
            [],
            $this->authHeaders($rider)
        );
        $accept->assertOk()->assertJsonPath('status', Order::STATUS_ASSIGNED);
        $this->assertArrayNotHasKey('pickup_otp', $accept->json());

        $pickupOtp = Order::find($orderId)->pickup_otp;
        $this->assertMatchesRegularExpression('/^\d{4}$/', $pickupOtp);

        // 3. Wrong pickup OTP is rejected.
        $badPickup = $this->postJson(
            "/api/v1/orders/{$orderId}/pickup",
            ['otp' => '0000'],
            $this->authHeaders($rider)
        );
        $badPickup->assertStatus(422)->assertJsonPath('code', 'OTP_INVALID');

        // 4. Correct pickup OTP → picked_up + delivery OTP generated.
        $pickup = $this->postJson(
            "/api/v1/orders/{$orderId}/pickup",
            ['otp' => $pickupOtp],
            $this->authHeaders($rider)
        );
        $pickup->assertOk()->assertJsonPath('status', Order::STATUS_PICKED_UP);

        $deliveryOtp = Order::find($orderId)->delivery_otp;
        $this->assertMatchesRegularExpression('/^\d{4}$/', $deliveryOtp);

        // 5. Correct delivery OTP → delivered, payment row created.
        $deliver = $this->postJson(
            "/api/v1/orders/{$orderId}/deliver",
            ['otp' => $deliveryOtp],
            $this->authHeaders($rider)
        );
        $deliver->assertOk()->assertJsonPath('status', Order::STATUS_DELIVERED);

        /** @var Order $done */
        $done = Order::find($orderId);
        $this->assertNotNull($done->delivered_at);
        $this->assertEquals(5000, $done->payment->amount_paise);
        $this->assertEquals('pending', $done->payment->status);
        $this->assertEquals(1, $rider->riderProfile->fresh()->total_trips);

        // 6. Rider earnings reflect the trip.
        $earnings = $this->getJson('/api/v1/rider/earnings', $this->authHeaders($rider));
        $earnings->assertOk()
            ->assertJsonPath('today_paise', 4750)
            ->assertJsonPath('total_trips', 1);
    }

    public function test_customer_cannot_create_order_with_client_fare(): void
    {
        $customer = $this->makeCustomer();

        $response = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'A',
            'pickup_lat' => 17.4833,
            'pickup_lng' => 78.4100,
            'drop_address' => 'B',
            'drop_lat' => 17.4923, // ~1 km
            'drop_lng' => 78.4100,
            'fare_paise' => 1, // ignored
            'platform_fee_paise' => 0, // ignored
        ], $this->authHeaders($customer));

        $response->assertCreated();
        // ~1 km → base fare 3000, regardless of what the client sent.
        $this->assertEquals(3000, $response->json('fare_paise'));
    }

    public function test_cancel_before_pickup(): void
    {
        $customer = $this->makeCustomer();
        $this->makeRider();

        $create = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'A',
            'pickup_lat' => 17.4833,
            'pickup_lng' => 78.4100,
            'drop_address' => 'B',
            'drop_lat' => 17.4923,
            'drop_lng' => 78.4100,
        ], $this->authHeaders($customer));
        $orderId = $create->json('id');

        $cancel = $this->postJson("/api/v1/orders/{$orderId}/cancel", [], $this->authHeaders($customer));
        $cancel->assertOk()->assertJsonPath('status', Order::STATUS_CANCELLED);
    }
}
