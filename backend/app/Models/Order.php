<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Order extends Model
{
    public const STATUS_REQUESTED = 'requested';
    public const STATUS_ASSIGNED = 'assigned';
    public const STATUS_PICKED_UP = 'picked_up';
    public const STATUS_DELIVERED = 'delivered';
    public const STATUS_CANCELLED = 'cancelled';

    protected $fillable = [
        'customer_id',
        'rider_id',
        'candidate_rider_ids',
        'pickup_address',
        'pickup_lat',
        'pickup_lng',
        'drop_address',
        'drop_lat',
        'drop_lng',
        'distance_km',
        'fare_paise',
        'platform_fee_paise',
        'rider_earning_paise',
        'parcel_type',
        'parcel_photo_path',
        'status',
        'assignment_expires_at',
        'pickup_otp',
        'pickup_otp_expires_at',
        'delivery_otp',
        'delivery_otp_expires_at',
        'payment_mode',
        'payment_status',
        'assigned_at',
        'picked_up_at',
        'delivered_at',
    ];

    protected function casts(): array
    {
        return [
            'candidate_rider_ids' => 'array',
            'assignment_expires_at' => 'datetime',
            'pickup_otp_expires_at' => 'datetime',
            'delivery_otp_expires_at' => 'datetime',
            'assigned_at' => 'datetime',
            'picked_up_at' => 'datetime',
            'delivered_at' => 'datetime',
        ];
    }

    // Never expose OTPs in API responses.
    protected $hidden = [
        'pickup_otp',
        'delivery_otp',
    ];

    public function customer()
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    public function rider()
    {
        return $this->belongsTo(User::class, 'rider_id');
    }

    public function payment()
    {
        return $this->hasOne(Payment::class);
    }

    public function isAssignmentExpired(): bool
    {
        return $this->assignment_expires_at !== null
            && $this->assignment_expires_at->isPast();
    }
}
