<?php

namespace Tests\Feature;

use App\Services\FareService;
use App\Services\GeoService;

/**
 * Fare math: ₹30 base covers the first 3 km, then ₹10/km (rounded up).
 * All money in PAISE (integers) — never floats.
 */
class FareQuoteTest extends SwiftDropTestCase
{
    private const PICKUP = [17.4833, 78.4100];

    private function pointKmNorth(float $km): array
    {
        // ~111.19 km per degree of latitude at Hyderabad's latitude.
        return [self::PICKUP[0] + ($km / 111.19), self::PICKUP[1]];
    }

    public function test_zero_distance_charges_base_fare(): void
    {
        $quote = FareService::quote(...[...self::PICKUP, ...self::PICKUP]);

        $this->assertEquals(0.0, $quote['distance_km']);
        $this->assertEquals(3000, $quote['fare_paise']); // ₹30 minimum
        $this->assertEquals(150, $quote['platform_fee_paise']); // 5%
        $this->assertEquals(2850, $quote['rider_earning_paise']); // 95%
    }

    public function test_exactly_three_km_charges_only_base(): void
    {
        [$lat, $lng] = $this->pointKmNorth(2.999);
        $quote = FareService::quote(...[...self::PICKUP, $lat, $lng]);

        $this->assertLessThanOrEqual(3.0, $quote['distance_km']);
        $this->assertEquals(3000, $quote['fare_paise']);
    }

    public function test_five_km_fare_is_fifty_rupees(): void
    {
        [$lat, $lng] = $this->pointKmNorth(4.99);
        $quote = FareService::quote(...[...self::PICKUP, $lat, $lng]);

        // 4.99 km → 2 extra km (ceil) → 3000 + 2×1000 = 5000 paise = ₹50
        $this->assertEquals(5000, $quote['fare_paise']);
        $this->assertEquals(250, $quote['platform_fee_paise']);
        $this->assertEquals(4750, $quote['rider_earning_paise']);
    }

    public function test_partial_km_rounds_up(): void
    {
        [$lat, $lng] = $this->pointKmNorth(3.1);
        $quote = FareService::quote(...[...self::PICKUP, $lat, $lng]);

        // 3.1 km → 1 extra km (ceil) → 4000 paise
        $this->assertEquals(4000, $quote['fare_paise']);
    }

    public function test_all_amounts_are_integers(): void
    {
        [$lat, $lng] = $this->pointKmNorth(7.77);
        $quote = FareService::quote(...[...self::PICKUP, $lat, $lng]);

        $this->assertIsInt($quote['fare_paise']);
        $this->assertIsInt($quote['platform_fee_paise']);
        $this->assertIsInt($quote['rider_earning_paise']);
        $this->assertEquals(
            $quote['fare_paise'],
            $quote['platform_fee_paise'] + $quote['rider_earning_paise']
        );
    }

    public function test_api_quote_returns_breakdown(): void
    {
        [$lat, $lng] = $this->pointKmNorth(4.99);

        $response = $this->postJson('/api/v1/fare/quote', [
            'pickup_lat' => self::PICKUP[0],
            'pickup_lng' => self::PICKUP[1],
            'drop_lat' => $lat,
            'drop_lng' => $lng,
        ], $this->jsonHeaders());

        $response->assertOk()
            ->assertJsonPath('fare_paise', 5000)
            ->assertJsonStructure(['distance_km', 'fare_paise', 'platform_fee_paise', 'rider_earning_paise', 'breakdown']);
    }

    public function test_api_quote_rejects_out_of_zone(): void
    {
        // Miyapur point — inside the INACTIVE zone.
        $response = $this->postJson('/api/v1/fare/quote', [
            'pickup_lat' => 17.5150,
            'pickup_lng' => 78.3650,
            'drop_lat' => 17.4833,
            'drop_lng' => 78.4100,
        ], $this->jsonHeaders());

        $response->assertStatus(422)->assertJsonPath('code', 'OUT_OF_ZONE');
    }
}
