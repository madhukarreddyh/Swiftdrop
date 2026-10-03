<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('rider_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('aadhaar', 20)->nullable();
            $table->string('licence_no', 30)->nullable();
            $table->string('bike_rc', 30)->nullable();
            $table->string('bike_number', 20)->nullable();
            $table->string('bank_account', 34)->nullable();
            $table->enum('verification_status', ['pending', 'approved', 'rejected'])->default('pending');
            $table->decimal('rating', 3, 2)->default(5.00);
            $table->unsignedInteger('total_trips')->default(0);
            $table->boolean('is_online')->default(false);
            $table->decimal('last_lat', 10, 7)->nullable();
            $table->decimal('last_lng', 10, 7)->nullable();
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();

            $table->index(['is_online', 'verification_status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('rider_profiles');
    }
};
