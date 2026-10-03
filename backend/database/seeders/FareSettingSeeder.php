<?php

namespace Database\Seeders;

use App\Models\FareSetting;
use Illuminate\Database\Seeder;

class FareSettingSeeder extends Seeder
{
    public function run(): void
    {
        FareSetting::seedDefaults();
    }
}
