<?php

namespace App\Services;

use App\Models\FareSetting;

/**
 * Server-side fare calculation. The client NEVER decides the price.
 * All money in PAISE (integers) — never floats.
 */
class FareService
{
    /**
     * @return array{distance_km: float, fare_paise: int, platform_fee_paise: int, rider_earning_paise: int, breakdown: array}
     */
    public static function quote(float $pickupLat, float $pickupLng, float $dropLat, float $dropLng): array
    {
        $baseFare = (int) FareSetting::get('base_fare_paise');   // 3000 = ₹30
        $baseKm = (float) FareSetting::get('base_km');           // 3
        $perKm = (int) FareSetting::get('per_km_paise');         // 1000 = ₹10/km
        $minFare = (int) FareSetting::get('min_fare_paise');     // 3000
        $commissionPct = (int) FareSetting::get('platform_commission_pct'); // 5

        $distanceKm = GeoService::haversineKm($pickupLat, $pickupLng, $dropLat, $dropLng);

        // Extra km beyond the base, rounded UP to the next whole km.
        $extraKm = (int) ceil(max(0.0, $distanceKm - $baseKm));

        $fare = $baseFare + ($extraKm * $perKm);
        $fare = max($fare, $minFare);

        // Integer-only commission split: platform 5%, rider keeps the rest.
        $platformFee = (int) round($fare * $commissionPct / 100);
        $riderEarning = $fare - $platformFee;

        return [
            'distance_km' => $distanceKm,
            'fare_paise' => $fare,
            'platform_fee_paise' => $platformFee,
            'rider_earning_paise' => $riderEarning,
            'breakdown' => [
                ['label' => "Base fare (first {$baseKm} km)", 'amount_paise' => $baseFare],
                ['label' => "Distance fare ({$extraKm} km × ₹" . number_format($perKm / 100, 2) . ')', 'amount_paise' => $extraKm * $perKm],
            ],
        ];
    }
}
