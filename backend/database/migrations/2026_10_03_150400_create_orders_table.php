<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->constrained('users');
            $table->foreignId('rider_id')->nullable()->constrained('users');
            // Rider IDs offered this order (broadcast matching); first accept wins.
            $table->json('candidate_rider_ids')->nullable();

            $table->string('pickup_address');
            $table->decimal('pickup_lat', 10, 7);
            $table->decimal('pickup_lng', 10, 7);
            $table->string('drop_address');
            $table->decimal('drop_lat', 10, 7);
            $table->decimal('drop_lng', 10, 7);

            $table->decimal('distance_km', 8, 3);
            // All money in PAISE (integers). Never floats.
            $table->unsignedInteger('fare_paise');
            $table->unsignedInteger('platform_fee_paise');
            $table->unsignedInteger('rider_earning_paise');

            $table->string('parcel_type')->nullable();
            $table->string('parcel_photo_path')->nullable();

            $table->enum('status', ['requested', 'assigned', 'picked_up', 'delivered', 'cancelled'])
                ->default('requested');
            $table->timestamp('assignment_expires_at')->nullable();

            $table->char('pickup_otp', 4)->nullable();
            $table->timestamp('pickup_otp_expires_at')->nullable();
            $table->char('delivery_otp', 4)->nullable();
            $table->timestamp('delivery_otp_expires_at')->nullable();

            $table->enum('payment_mode', ['upi', 'cash'])->default('upi');
            $table->enum('payment_status', ['pending', 'paid', 'failed'])->default('pending');

            $table->timestamp('assigned_at')->nullable();
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'created_at']);
            $table->index('customer_id');
            $table->index('rider_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
