<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Zone;
use App\Services\FareService;
use App\Services\GeoService;
use Illuminate\Http\Request;

class FareController extends Controller
{
    /**
     * POST /api/v1/fare/quote
     * {pickup_lat, pickup_lng, drop_lat, drop_lng}
     * Server-side only — the client never decides the price.
     */
    public function quote(Request $request)
    {
        $data = $request->validate([
            'pickup_lat' => ['required', 'numeric', 'between:-90,90'],
            'pickup_lng' => ['required', 'numeric', 'between:-180,180'],
            'drop_lat' => ['required', 'numeric', 'between:-90,90'],
            'drop_lng' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $inPickupZone = $this->insideActiveZone($data['pickup_lat'], $data['pickup_lng']);
        $inDropZone = $this->insideActiveZone($data['drop_lat'], $data['drop_lng']);

        if (!$inPickupZone || !$inDropZone) {
            return response()->json([
                'message' => "We haven't reached this area yet.",
                'code' => 'OUT_OF_ZONE',
            ], 422);
        }

        $quote = FareService::quote(
            $data['pickup_lat'], $data['pickup_lng'],
            $data['drop_lat'], $data['drop_lng']
        );

        return response()->json($quote);
    }

    private function insideActiveZone(float $lat, float $lng): bool
    {
        foreach (Zone::active()->get(['polygon']) as $zone) {
            if (GeoService::pointInPolygon($lat, $lng, $zone->polygon)) {
                return true;
            }
        }

        return false;
    }
}
