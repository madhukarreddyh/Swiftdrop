<?php

use App\Http\Controllers\Api\V1\AdminController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\FareController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\RiderController;
use App\Http\Controllers\Api\V1\SupportController;
use App\Http\Controllers\Api\V1\WebhookController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| SwiftDrop API v1
|--------------------------------------------------------------------------
| All money in PAISE (integers). Fares are computed server-side only.
*/

Route::prefix('v1')->group(function () {
    // Public
    Route::post('auth/otp/send', [AuthController::class, 'sendOtp']);
    Route::post('auth/otp/verify', [AuthController::class, 'verifyOtp']);
    Route::post('fare/quote', [FareController::class, 'quote']);
    Route::post('webhooks/razorpay', [WebhookController::class, 'razorpay']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);

        // Orders
        Route::post('orders', [OrderController::class, 'store']);
        Route::get('orders', [OrderController::class, 'index']);
        Route::get('orders/{order}', [OrderController::class, 'show']);
        Route::post('orders/{order}/cancel', [OrderController::class, 'cancel']);
        Route::post('orders/{order}/otp/refresh', [OrderController::class, 'refreshOtp']);

        // Rider order flow
        Route::middleware('role:rider')->group(function () {
            Route::post('orders/{order}/accept', [OrderController::class, 'accept']);
            Route::post('orders/{order}/pickup', [OrderController::class, 'pickup']);
            Route::post('orders/{order}/deliver', [OrderController::class, 'deliver']);

            Route::post('rider/online', [RiderController::class, 'setOnline']);
            Route::post('rider/location', [RiderController::class, 'updateLocation'])
                ->middleware('throttle:30,1');
            Route::post('rider/documents', [RiderController::class, 'submitDocuments']);
            Route::get('rider/earnings', [RiderController::class, 'earnings']);
            Route::get('rider/orders', [RiderController::class, 'orders']);
            Route::get('rider/profile', [RiderController::class, 'profile_show']);
        });

        // Admin
        Route::middleware('role:admin')->prefix('admin')->group(function () {
            Route::get('orders', [AdminController::class, 'orders']);
            Route::get('riders', [AdminController::class, 'riders']);
            Route::post('riders/{id}/verify', [AdminController::class, 'verifyRider']);
            Route::get('fare-settings', [AdminController::class, 'fareSettings']);
            Route::put('fare-settings', [AdminController::class, 'updateFareSettings']);
            Route::get('zones', [AdminController::class, 'zones']);
            Route::post('zones', [AdminController::class, 'createZone']);
            Route::put('zones/{zone}', [AdminController::class, 'updateZone']);
            Route::post('payouts/generate', [AdminController::class, 'generatePayouts']);
            Route::get('payouts', [AdminController::class, 'payouts']);
        });

        // Support (customers/riders see own; admin sees all)
        Route::post('support/tickets', [SupportController::class, 'store']);
        Route::get('support/tickets', [SupportController::class, 'index']);
        Route::post('support/tickets/{ticket}/reply', [SupportController::class, 'reply']);
    });
});
