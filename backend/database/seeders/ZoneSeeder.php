<?php

namespace Database\Seeders;

use App\Models\Zone;
use Illuminate\Database\Seeder;

/**
 * Launch zones for Hyderabad. Polygons are rough rectangles —
 * replace with precise GHMC boundaries before production.
 * Miyapur ships INACTIVE to demonstrate the "Notify Me" waitlist flow.
 */
class ZoneSeeder extends Seeder
{
    public function run(): void
    {
        $zones = [
            [
                'name' => 'Kukatpally',
                'polygon' => [
                    [17.4945, 78.3999],
                    [17.4945, 78.4260],
                    [17.4720, 78.4260],
                    [17.4720, 78.3999],
                ],
                'is_active' => true,
            ],
            [
                'name' => 'KPHB',
                'polygon' => [
                    [17.4900, 78.3850],
                    [17.4900, 78.4000],
                    [17.4700, 78.4000],
                    [17.4700, 78.3850],
                ],
                'is_active' => true,
            ],
            [
                'name' => 'Moosapet',
                'polygon' => [
                    [17.4720, 78.4260],
                    [17.4720, 78.4450],
                    [17.4550, 78.4450],
                    [17.4550, 78.4260],
                ],
                'is_active' => true,
            ],
            [
                'name' => 'Miyapur',
                'polygon' => [
                    [17.5200, 78.3600],
                    [17.5200, 78.3800],
                    [17.5000, 78.3800],
                    [17.5000, 78.3600],
                ],
                'is_active' => false,
            ],
        ];

        foreach ($zones as $zone) {
            Zone::updateOrCreate(['name' => $zone['name']], $zone);
        }
    }
}
