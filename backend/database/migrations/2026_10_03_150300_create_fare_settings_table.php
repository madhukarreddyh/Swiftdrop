<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('fare_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            // Money stored in PAISE (integers). Never floats.
            $table->string('value');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fare_settings');
    }
};
