<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RiderProfile extends Model
{
    protected $fillable = [
        'user_id',
        'aadhaar',
        'licence_no',
        'bike_rc',
        'bike_number',
        'bank_account',
        'verification_status',
        'rating',
        'total_trips',
        'is_online',
        'last_lat',
        'last_lng',
        'last_seen_at',
    ];

    protected function casts(): array
    {
        return [
            'is_online' => 'boolean',
            'last_seen_at' => 'datetime',
            'rating' => 'decimal:2',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function scopeApproved($query)
    {
        return $query->where('verification_status', 'approved');
    }

    public function scopeOnline($query)
    {
        return $query->where('is_online', true)
            ->where('last_seen_at', '>=', now()->subMinutes(5));
    }
}
