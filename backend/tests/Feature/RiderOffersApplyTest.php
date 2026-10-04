<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\RiderProfile;

/**
 * v1 additive endpoints for the rider app:
 * - POST /api/v1/rider/apply  (partner application: customer -> rider, pending)
 * - GET  /api/v1/rider/offers (pollable pending offers for the rider)
 */
class RiderOffersApplyTest extends SwiftDropTestCase
{
    private function applyPayload(): array
    {
        return [
            'name' => 'Ravi Kumar',
            'aadhaar' => '123456789012',
            'licence_no' => 'TS09 20210012345',
            'bike_rc' => 'TS09AB1234',
            'bike_number' => 'TS 09 AB 1234',
            'vehicle_type' => 'bike',
            'bank_account' => '50100234567891',
        ];
    }

    private function createOrder($customer): int
    {
        $res = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'KPHB Colony, Road 5',
            'pickup_lat' => 17.4833,
            'pickup_lng' => 78.4100,
            'drop_address' => 'Kukatpally Metro',
            'drop_lat' => 17.5282,
            'drop_lng' => 78.4100,
            'parcel_type' => 'Documents',
            'payment_mode' => 'upi',
        ], $this->authHeaders($customer));

        $res->assertCreated();

        return $res->json('id');
    }

    public function test_apply_flips_customer_to_pending_rider(): void
    {
        $customer = $this->makeCustomer('9876543220');

        $res = $this->postJson(
            '/api/v1/rider/apply',
            $this->applyPayload(),
            $this->authHeaders($customer)
        );

        $res->assertOk()
            ->assertJsonPath('user.role', 'rider')
            ->assertJsonPath('profile.verification_status', 'pending');

        $this->assertTrue($customer->fresh()->isRider());
        $profile = RiderProfile::where('user_id', $customer->id)->first();
        $this->assertNotNull($profile);
        $this->assertEquals('TS 09 AB 1234', $profile->bike_number);
    }

    public function test_apply_rejected_for_already_verified_rider(): void
    {
        $rider = $this->makeRider('9876543221', approved: true);

        $res = $this->postJson(
            '/api/v1/rider/apply',
            $this->applyPayload(),
            $this->authHeaders($rider)
        );

        $res->assertStatus(422)->assertJsonPath('code', 'ALREADY_VERIFIED');
    }

    public function test_apply_requires_all_documents(): void
    {
        $customer = $this->makeCustomer('9876543222');

        $res = $this->postJson(
            '/api/v1/rider/apply',
            ['name' => 'Ravi'],
            $this->authHeaders($customer)
        );

        $res->assertStatus(422);
        $this->assertFalse($customer->fresh()->isRider());
    }

    public function test_offers_returns_pending_offer_for_candidate(): void
    {
        $customer = $this->makeCustomer('9876543230');
        $rider = $this->makeRider('9876543231', approved: true, online: true);
        $other = $this->makeRider('9876543232', approved: true, online: true);

        $orderId = $this->createOrder($customer);

        /** @var Order $order */
        $order = Order::findOrFail($orderId);
        $this->assertContains($rider->id, $order->candidate_rider_ids);

        $res = $this->getJson(
            '/api/v1/rider/offers',
            $this->authHeaders($rider)
        );
        $res->assertOk();
        $ids = collect($res->json('offers'))->pluck('id')->all();
        $this->assertContains($orderId, $ids);

        // The other rider may or may not be a candidate; offers must not
        // leak to riders who were not offered this order.
        $otherRes = $this->getJson(
            '/api/v1/rider/offers',
            $this->authHeaders($other)
        );
        $otherRes->assertOk();
        $otherIds = collect($otherRes->json('offers'))->pluck('id')->all();
        $isCandidate = in_array($other->id, $order->candidate_rider_ids, true);
        $this->assertEquals($isCandidate, in_array($orderId, $otherIds, true));

        // OTPs must never leak through offers.
        foreach ($res->json('offers') as $offer) {
            $this->assertArrayNotHasKey('pickup_otp', $offer);
            $this->assertArrayNotHasKey('delivery_otp', $offer);
        }
    }

    public function test_offers_empty_after_accept(): void
    {
        $customer = $this->makeCustomer('9876543240');
        $rider = $this->makeRider('9876543241', approved: true, online: true);

        $orderId = $this->createOrder($customer);

        $accept = $this->postJson(
            "/api/v1/orders/{$orderId}/accept",
            [],
            $this->authHeaders($rider)
        );
        $accept->assertOk();

        $res = $this->getJson(
            '/api/v1/rider/offers',
            $this->authHeaders($rider)
        );
        $res->assertOk()->assertJsonPath('offers', []);
    }

    public function test_offers_requires_rider_role(): void
    {
        $customer = $this->makeCustomer('9876543250');

        $res = $this->getJson(
            '/api/v1/rider/offers',
            $this->authHeaders($customer)
        );
        // role:rider middleware forbids customers.
        $this->assertContains($res->getStatusCode(), [401, 403]);
    }

    public function test_apply_rejects_invalid_vehicle_type(): void
    {
        $customer = $this->makeCustomer('9876543260');

        $payload = $this->applyPayload();
        $payload['vehicle_type'] = 'truck';

        $res = $this->postJson(
            '/api/v1/rider/apply',
            $payload,
            $this->authHeaders($customer)
        );

        $res->assertStatus(422)->assertJsonValidationErrors('vehicle_type');
        $this->assertFalse($customer->fresh()->isRider());
    }

    public function test_apply_rejects_missing_vehicle_type(): void
    {
        $customer = $this->makeCustomer('9876543261');

        $payload = $this->applyPayload();
        unset($payload['vehicle_type']);

        $res = $this->postJson(
            '/api/v1/rider/apply',
            $payload,
            $this->authHeaders($customer)
        );

        $res->assertStatus(422)->assertJsonValidationErrors('vehicle_type');
        $this->assertFalse($customer->fresh()->isRider());
    }

    public function test_apply_accepts_bike_and_auto_vehicle_types(): void
    {
        foreach (['bike', 'auto'] as $i => $type) {
            $customer = $this->makeCustomer('98765432' . (70 + $i));

            $payload = $this->applyPayload();
            $payload['vehicle_type'] = $type;

            $res = $this->postJson(
                '/api/v1/rider/apply',
                $payload,
                $this->authHeaders($customer)
            );

            $res->assertOk();
            $profile = RiderProfile::where('user_id', $customer->id)->first();
            $this->assertNotNull($profile);
            $this->assertEquals($type, $profile->vehicle_type);
        }
    }
}
