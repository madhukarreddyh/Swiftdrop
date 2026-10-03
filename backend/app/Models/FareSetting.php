<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

class FareSetting extends Model
{
    protected $fillable = ['key', 'value'];

    public const DEFAULTS = [
        // Money in PAISE. base_fare 3000 = ₹30 covers first base_km.
        'base_fare_paise' => '3000',
        'base_km' => '3',
        'per_km_paise' => '1000',   // ₹10 per extra km
        'night_charge_paise' => '0',
        'min_fare_paise' => '3000',
        'platform_commission_pct' => '5', // platform takes 5%, rider keeps 95%
    ];

    public static function get(string $key): string
    {
        return Cache::rememberForever("fare_setting:{$key}", function () use ($key) {
            $row = static::where('key', $key)->first();
            if ($row) {
                return $row->value;
            }
            return static::DEFAULTS[$key] ?? '';
        });
    }

    public static function set(string $key, string $value): void
    {
        static::updateOrCreate(['key' => $key], ['value' => $value]);
        Cache::forget("fare_setting:{$key}");
    }

    public static function seedDefaults(): void
    {
        foreach (static::DEFAULTS as $key => $value) {
            static::firstOrCreate(['key' => $key], ['value' => $value]);
        }
        foreach (static::DEFAULTS as $key => $value) {
            Cache::forget("fare_setting:{$key}");
        }
    }
}
