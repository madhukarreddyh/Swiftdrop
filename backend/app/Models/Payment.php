<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Payment extends Model
{
    protected $fillable = [
        'order_id',
        'razorpay_order_id',
        'razorpay_payment_id',
        'amount_paise',
        'status',
        'signature_verified',
    ];

    protected function casts(): array
    {
        return ['signature_verified' => 'boolean'];
    }

    public function order()
    {
        return $this->belongsTo(Order::class);
    }
}
