<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Dev-only admin account. Change the phone and use OTP login in production.
 */
class AdminSeeder extends Seeder
{
    public function run(): void
    {
        User::firstOrCreate(
            ['phone' => '9000000001'],
            [
                'name' => 'SwiftDrop Admin',
                'role' => 'admin',
                'email' => 'admin@swiftdrop.local',
                // Admins log in via OTP like everyone else; this is a non-empty placeholder.
                'password' => bcrypt(str()->random(32)),
            ]
        );
    }
}
