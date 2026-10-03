<?php

namespace App\Services;

/**
 * Geographic calculations: haversine distance and point-in-polygon.
 */
class GeoService
{
    private const EARTH_RADIUS_KM = 6371.0;

    /**
     * Great-circle distance between two points in kilometres.
     */
    public static function haversineKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return round(2 * self::EARTH_RADIUS_KM * asin(sqrt($a)), 3);
    }

    /**
     * Ray-casting point-in-polygon.
     * Polygon: array of [lat, lng] pairs.
     */
    public static function pointInPolygon(float $lat, float $lng, array $polygon): bool
    {
        $inside = false;
        $n = count($polygon);
        if ($n < 3) {
            return false;
        }

        for ($i = 0, $j = $n - 1; $i < $n; $j = $i++) {
            [$latI, $lngI] = $polygon[$i];
            [$latJ, $lngJ] = $polygon[$j];

            $intersects = (($lngI > $lng) !== ($lngJ > $lng))
                && ($lat < ($latJ - $latI) * ($lng - $lngI) / ($lngJ - $lngI) + $latI);

            if ($intersects) {
                $inside = !$inside;
            }
        }

        return $inside;
    }
}
