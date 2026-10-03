<?php

namespace App\Services;

use App\Models\Order;
use App\Models\RiderProfile;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Matches a new order to the nearest available riders.
 * Broadcasts to up to 3 nearest riders; the FIRST accept wins (atomic).
 * Unaccepted assignments expire after 60 seconds and are re-dispatched.
 */
class MatchingService
{
    public const ASSIGNMENT_TTL_SECONDS = 60;
    public const MAX_CANDIDATES = 3;

    /**
     * Find candidate riders near the pickup point and attach them to the order.
     *
     * @param int[] $excludeUserIds rider user-ids already tried (for re-dispatch)
     */
    public static function dispatch(Order $order, array $excludeUserIds = []): bool
    {
        $candidates = RiderProfile::approved()
            ->online()
            ->whereNotNull('last_lat')
            ->whereNotNull('last_lng')
            ->whereNotIn('user_id', $excludeUserIds)
            ->with('user')
            ->get()
            ->map(fn (RiderProfile $p) => [
                'user_id' => $p->user_id,
                'distance_km' => GeoService::haversineKm(
                    (float) $order->pickup_lat,
                    (float) $order->pickup_lng,
                    (float) $p->last_lat,
                    (float) $p->last_lng
                ),
            ])
            ->sortBy('distance_km')
            ->take(self::MAX_CANDIDATES)
            ->pluck('user_id')
            ->values()
            ->all();

        if (empty($candidates)) {
            return false;
        }

        $order->update([
            'candidate_rider_ids' => $candidates,
            'assignment_expires_at' => now()->addSeconds(self::ASSIGNMENT_TTL_SECONDS),
        ]);

        // TODO: push notification to candidate riders (FCM).

        return true;
    }

    /**
     * Atomic accept: exactly one rider wins, even under concurrent requests.
     *
     * @return array{ok: bool, error?: string}
     */
    public static function accept(Order $order, User $rider): array
    {
        return DB::transaction(function () use ($order, $rider) {
            /** @var Order $locked */
            $locked = Order::whereKey($order->id)->lockForUpdate()->first();

            if ($locked->status !== Order::STATUS_REQUESTED) {
                return ['ok' => false, 'error' => 'ALREADY_TAKEN'];
            }
            if ($locked->isAssignmentExpired()) {
                return ['ok' => false, 'error' => 'ASSIGNMENT_EXPIRED'];
            }
            $candidates = $locked->candidate_rider_ids ?? [];
            if (!in_array($rider->id, $candidates, true)) {
                return ['ok' => false, 'error' => 'NOT_OFFERED'];
            }

            $locked->update([
                'rider_id' => $rider->id,
                'status' => Order::STATUS_ASSIGNED,
                'assigned_at' => now(),
                'assignment_expires_at' => null,
                'pickup_otp' => (string) random_int(1000, 9999),
                'pickup_otp_expires_at' => now()->addMinutes(10),
            ]);

            return ['ok' => true];
        });
    }

    /**
     * Re-dispatch orders whose assignment expired without an accept.
     *
     * @return int number of orders re-dispatched
     */
    public static function reassignExpired(): int
    {
        $count = 0;

        $expired = Order::where('status', Order::STATUS_REQUESTED)
            ->whereNotNull('assignment_expires_at')
            ->where('assignment_expires_at', '<', now())
            ->get();

        foreach ($expired as $order) {
            $tried = $order->candidate_rider_ids ?? [];
            $order->update([
                'candidate_rider_ids' => null,
                'assignment_expires_at' => null,
            ]);
            // First try riders who haven't been offered yet; if nobody new is
            // available, re-broadcast to everyone with a fresh 60s window so
            // the order never dies silently.
            if (!self::dispatch($order->fresh(), $tried)) {
                self::dispatch($order->fresh(), []);
            }
            $count++;
        }

        return $count;
    }
}
