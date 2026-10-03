<?php

namespace Tests\Feature;

use App\Models\Order;

/**
 * Accept race: when an order is offered to several riders,
 * exactly ONE accept wins. Everyone else gets 409.
 */
class DoubleAcceptTest extends SwiftDropTestCase
{
    public function test_only_first_accept_wins(): void
    {
        $customer = $this->makeCustomer('9876543210');
        $riderA = $this->makeRider('9876543211', lat: 17.4840, lng: 78.4105);
        $riderB = $this->makeRider('9876543212', lat: 17.4825, lng: 78.4095);

        $create = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'KPHB Colony, Road 5',
            'pickup_lat' => 17.4833,
            'pickup_lng' => 78.4100,
            'drop_address' => 'Kukatpally Metro',
            'drop_lat' => 17.4923,
            'drop_lng' => 78.4100,
        ], $this->authHeaders($customer));
        $create->assertCreated();
        $orderId = $create->json('id');

        $candidates = Order::find($orderId)->candidate_rider_ids;
        $this->assertContains($riderA->id, $candidates);
        $this->assertContains($riderB->id, $candidates);

        // Rider A accepts first — wins.
        $first = $this->postJson("/api/v1/orders/{$orderId}/accept", [], $this->authHeaders($riderA));
        $first->assertOk()->assertJsonPath('rider_id', $riderA->id);

        // Rider B accepts a moment later — loses.
        $second = $this->postJson("/api/v1/orders/{$orderId}/accept", [], $this->authHeaders($riderB));
        $second->assertStatus(409)->assertJsonPath('code', 'ALREADY_TAKEN');

        $this->assertEquals($riderA->id, Order::find($orderId)->rider_id);
    }

    public function test_double_tap_by_same_rider_is_idempotent(): void
    {
        $customer = $this->makeCustomer('9876543210');
        $rider = $this->makeRider('9876543211');

        $create = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'A',
            'pickup_lat' => 17.4833,
            'pickup_lng' => 78.4100,
            'drop_address' => 'B',
            'drop_lat' => 17.4923,
            'drop_lng' => 78.4100,
        ], $this->authHeaders($customer));
        $orderId = $create->json('id');

        $this->postJson("/api/v1/orders/{$orderId}/accept", [], $this->authHeaders($rider))->assertOk();

        // Second tap: order is no longer "requested".
        $retry = $this->postJson("/api/v1/orders/{$orderId}/accept", [], $this->authHeaders($rider));
        $retry->assertStatus(409)->assertJsonPath('code', 'ALREADY_TAKEN');
    }

    public function test_rider_not_offered_cannot_accept(): void
    {
        $customer = $this->makeCustomer('9876543210');
        $this->makeRider('9876543211'); // candidate
        $outsider = $this->makeRider('9876543299', online: false); // offline → not a candidate

        $create = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'A',
            'pickup_lat' => 17.4833,
            'pickup_lng' => 78.4100,
            'drop_address' => 'B',
            'drop_lat' => 17.4923,
            'drop_lng' => 78.4100,
        ], $this->authHeaders($customer));
        $orderId = $create->json('id');

        $attempt = $this->postJson("/api/v1/orders/{$orderId}/accept", [], $this->authHeaders($outsider));
        $attempt->assertStatus(409)->assertJsonPath('code', 'NOT_OFFERED');
    }

    public function test_expired_assignment_can_be_reassigned(): void
    {
        $customer = $this->makeCustomer('9876543210');
        $riderA = $this->makeRider('9876543211');
        $riderB = $this->makeRider('9876543212');

        $create = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'A',
            'pickup_lat' => 17.4833,
            'pickup_lng' => 78.4100,
            'drop_address' => 'B',
            'drop_lat' => 17.4923,
            'drop_lng' => 78.4100,
        ], $this->authHeaders($customer));
        $orderId = $create->json('id');

        // Force the assignment to expire.
        Order::whereKey($orderId)->update(['assignment_expires_at' => now()->subMinute()]);

        // Late accept fails…
        $late = $this->postJson("/api/v1/orders/{$orderId}/accept", [], $this->authHeaders($riderA));
        $late->assertStatus(409)->assertJsonPath('code', 'ASSIGNMENT_EXPIRED');

        // …and the reassign command re-offers it (fresh 60s window).
        $this->artisan('orders:reassign-expired')->assertSuccessful();

        $fresh = Order::find($orderId);
        $this->assertNotNull($fresh->candidate_rider_ids);
        $this->assertNotNull($fresh->assignment_expires_at);
        $this->assertContains($riderB->id, $fresh->candidate_rider_ids);

        $accept = $this->postJson("/api/v1/orders/{$orderId}/accept", [], $this->authHeaders($riderB));
        $accept->assertOk()->assertJsonPath('rider_id', $riderB->id);
    }
}
