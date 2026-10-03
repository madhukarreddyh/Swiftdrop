<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Payout extends Model
{
    protected $fillable = [
        'rider_id',
        'period_start',
        'period_end',
        'trips',
        'amount_paise',
        'bank_ref',
        'status',
        'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'period_start' => 'date',
            'period_end' => 'date',
            'paid_at' => 'datetime',
        ];
    }

    public function rider()
    {
        return $this->belongsTo(User::class, 'rider_id');
    }
}
