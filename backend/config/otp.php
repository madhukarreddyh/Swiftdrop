<?php

return [

    /*
    |--------------------------------------------------------------------------
    | OTP test mode
    |--------------------------------------------------------------------------
    |
    | When true, the OTP send endpoint includes the generated code in its
    | JSON response ("dev_code") so the mobile apps can be tested end-to-end
    | without an SMS provider wired up.
    |
    | NEVER enable in production (or any publicly reachable environment):
    | anyone could request login codes for any phone number and take over
    | accounts. Rate limiting stays active in test mode, but the code itself
    | must never be exposed outside controlled testing.
    |
    */

    'debug' => env('OTP_DEBUG', false),

];
