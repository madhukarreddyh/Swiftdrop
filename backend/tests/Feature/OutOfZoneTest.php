<?php

namespace Tests\Feature;

/**
 * Service-area enforcement: pickup AND drop must both sit inside an
 * ACTIVE zone, otherwise the API refuses with OUT_OF_ZONE.
 */
class OutOfZoneTest extends SwiftDropTestCase
{
    public function test_pickup_in_inactive_zone_is_rejected(): void
    {
        $customer = $this->makeCustomer();

        $response = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'Miyapur Metro',
            'pickup_lat' => 17.5150, // inside Miyapur polygon, which is INACTIVE
            'pickup_lng' => 78.3650,
            'drop_address' => 'KPHB Colony',
            'drop_lat' => 17.4833,
            'drop_lng' => 78.4100,
        ], $this->authHeaders($customer));

        $response->assertStatus(422)
            ->assertJsonPath('code', 'OUT_OF_ZONE')
            ->assertJsonPath('message', "We haven't reached this area yet.");
    }

    public function test_drop_outside_all_zones_is_rejected(): void
    {
        $customer = $this->makeCustomer();

        $response = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'KPHB Colony',
            'pickup_lat' => 17.4833,
            'pickup_lng' => 78.4100,
            'drop_address' => 'Nowhere',
            'drop_lat' => 17.6000, // outside every zone
            'drop_lng' => 78.6000,
        ], $this->authHeaders($customer));

        $response->assertStatus(422)->assertJsonPath('code', 'OUT_OF_ZONE');
    }

    public function test_in_zone_order_is_accepted(): void
    {
        $customer = $this->makeCustomer();
        $this->makeRider();

        $response = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'KPHB Colony',
            'pickup_lat' => 17.4833,
            'pickup_lng' => 78.4100,
            'drop_address' => 'Kukatpally',
            'drop_lat' => 17.4850,
            'drop_lng' => 78.4200,
        ], $this->authHeaders($customer));

        $response->assertCreated();
    }

    public function test_admin_can_activate_zone(): void
    {
        $admin = $this->makeAdmin();

        $zones = $this->getJson('/api/v1/admin/zones', $this->authHeaders($admin));
        $zones->assertOk();
        $miyapur = collect($zones->json())->firstWhere('name', 'Miyapur');
        $this->assertFalse($miyapur['is_active']);

        $update = $this->putJson(
            "/api/v1/admin/zones/{$miyapur['id']}",
            ['is_active' => true],
            $this->authHeaders($admin)
        );
        $update->assertOk()->assertJsonPath('is_active', true);

        // Now a Miyapur pickup works.
        $customer = $this->makeCustomer('9999999999');
        $this->makeRider('8888888888', lat: 17.5150, lng: 78.3650);

        $order = $this->postJson('/api/v1/orders', [
            'pickup_address' => 'Miyapur Metro',
            'pickup_lat' => 17.5150,
            'pickup_lng' => 78.3650,
            'drop_address' => 'Miyapur X Roads',
            'drop_lat' => 17.5100,
            'drop_lng' => 78.3700,
        ], $this->authHeaders($customer));

        $order->assertCreated();
    }

    public function test_non_admin_cannot_change_zones(): void
    {
        $customer = $this->makeCustomer();
        $zoneId = \App\Models\Zone::where('name', 'Kukatpally')->value('id');

        $response = $this->putJson("/api/v1/admin/zones/{$zoneId}", ['is_active' => false], $this->authHeaders($customer));
        $response->assertForbidden();
    }
}
