<?php

use App\Http\Controllers\Web\AdminAuthController;
use App\Http\Controllers\Web\AdminController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

/*
|--------------------------------------------------------------------------
| SwiftDrop admin panel (Blade)
|--------------------------------------------------------------------------
| Admin sign-in reuses the OTP system (AdminSeeder's 9000000001 in dev).
| Every panel page sits behind the 'admin' middleware.
*/
Route::prefix('admin')->name('admin.')->group(function () {
    Route::get('login', [AdminAuthController::class, 'showLogin'])->name('login');
    Route::post('login', [AdminAuthController::class, 'sendOtp'])->name('login.send');
    Route::get('login/verify', [AdminAuthController::class, 'showVerify'])->name('login.verify');
    Route::post('login/verify', [AdminAuthController::class, 'verify'])->name('login.verify.post');

    Route::middleware('admin')->group(function () {
        Route::post('logout', [AdminAuthController::class, 'logout'])->name('logout');

        Route::get('/', [AdminController::class, 'dashboard'])->name('dashboard');

        Route::get('riders', [AdminController::class, 'riders'])->name('riders');
        Route::get('riders/{rider}', [AdminController::class, 'riderShow'])->name('riders.show');
        Route::post('riders/{rider}/verify', [AdminController::class, 'verifyRider'])->name('riders.verify');

        Route::get('orders', [AdminController::class, 'orders'])->name('orders');
        Route::get('orders/{order}', [AdminController::class, 'orderShow'])->name('orders.show');

        Route::get('zones', [AdminController::class, 'zones'])->name('zones');
        Route::post('zones/{zone}/toggle', [AdminController::class, 'toggleZone'])->name('zones.toggle');

        Route::get('fare', [AdminController::class, 'fare'])->name('fare');
        Route::post('fare', [AdminController::class, 'updateFare'])->name('fare.update');

        Route::get('payouts', [AdminController::class, 'payouts'])->name('payouts');
        Route::post('payouts/generate', [AdminController::class, 'generatePayouts'])->name('payouts.generate');
        Route::post('payouts/{payout}/mark-paid', [AdminController::class, 'markPayoutPaid'])->name('payouts.mark-paid');
    });
});
