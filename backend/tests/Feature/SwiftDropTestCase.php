<?php

namespace Tests\Feature;

use App\Models\FareSetting;
use App\Models\RiderProfile;
use App\Models\User;
use App\Models\Zone;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Shared helpers: MySQL test DB (RefreshDatabase), seeded fare settings
 * and zones, and factories for customers / riders / admins with tokens.
 */
abstract class SwiftDropTestCase extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        FareSetting::seedDefaults();

        // Kukatpally test zone: generous rectangle around central Kukatpally.
        Zone::create([
            'name' => 'Kukatpally',
            'polygon' => [
                [17.5400, 78.3800],
                [17.5400, 78.4400],
                [17.4400, 78.4400],
                [17.4400, 78.3800],
            ],
            'is_active' => true,
        ]);

        // Inactive zone for out-of-zone tests.
        Zone::create([
            'name' => 'Miyapur',
            'polygon' => [
                [17.5300, 78.3500],
                [17.5300, 78.3800],
                [17.5000, 78.3800],
                [17.5000, 78.3500],
            ],
            'is_active' => false,
        ]);
    }

    protected function makeCustomer(string $phone = '9876543210'): User
    {
        return User::create([
            'name' => 'Test Customer',
            'phone' => $phone,
            'role' => 'customer',
            'password' => bcrypt('password'),
        ]);
    }

    protected function makeRider(
        string $phone = '9876543211',
        bool $approved = true,
        bool $online = true,
        float $lat = 17.4833,
        float $lng = 78.4100
    ): User {
        $user = User::create([
            'name' => 'Test Rider',
            'phone' => $phone,
            'role' => 'rider',
            'password' => bcrypt('password'),
        ]);

        RiderProfile::create([
            'user_id' => $user->id,
            'verification_status' => $approved ? 'approved' : 'pending',
            'is_online' => $online,
            'last_lat' => $lat,
            'last_lng' => $lng,
            'last_seen_at' => now(),
            'bike_number' => 'TS 09 AB 1234',
        ]);

        return $user->fresh();
    }

    protected function makeAdmin(string $phone = '9000000001'): User
    {
        return User::create([
            'name' => 'Test Admin',
            'phone' => $phone,
            'role' => 'admin',
            'password' => bcrypt('password'),
        ]);
    }

    protected function authHeaders(User $user): array
    {
        // Guards memoize the resolved user; in tests the container persists
        // across requests, so forget them to force fresh Bearer resolution.
        $this->app['auth']->forgetGuards();

        $token = $user->createToken('test')->plainTextToken;

        return [
            'Authorization' => "Bearer {$token}",
            'Accept' => 'application/json',
        ];
    }

    protected function jsonHeaders(): array
    {
        return ['Accept' => 'application/json'];
    }
}
