<?php

namespace App\Services;

use App\Models\Zone;

/**
 * Service-area checks: a point is servable only inside an ACTIVE zone.
 */
class ZoneService
{
    public static function insideActiveZone(float $lat, float $lng): bool
    {
        foreach (Zone::active()->get(['polygon']) as $zone) {
            if (GeoService::pointInPolygon($lat, $lng, $zone->polygon)) {
                return true;
            }
        }

        return false;
    }
}
