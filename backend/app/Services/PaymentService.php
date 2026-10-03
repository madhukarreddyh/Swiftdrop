<?php

namespace App\Services;

use App\Models\Order;
use App\Models\Payment;

/**
 * Payment handling. v1 ships with a FakeDriver (dev) behind a driver
 * interface so Razorpay can be plugged in without touching controllers.
 */
interface PaymentDriver
{
    /** @return array{provider_order_id: string} */
    public function createOrder(Order $order): array;

    public function verifyWebhookSignature(string $payload, string $signature): bool;
}

class FakePaymentDriver implements PaymentDriver
{
    public function createOrder(Order $order): array
    {
        return ['provider_order_id' => 'fake_order_' . $order->id . '_' . time()];
    }

    public function verifyWebhookSignature(string $payload, string $signature): bool
    {
        // Dev only: accept everything. Real driver verifies HMAC-SHA256.
        return true;
    }
}

class RazorpayPaymentDriver implements PaymentDriver
{
    public function createOrder(Order $order): array
    {
        // TODO: integrate razorpay/razorpay SDK with RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET.
        throw new \RuntimeException('Razorpay driver not configured yet.');
    }

    public function verifyWebhookSignature(string $payload, string $signature): bool
    {
        $secret = config('services.razorpay.webhook_secret', '');
        $expected = hash_hmac('sha256', $payload, $secret);
        return hash_equals($expected, $signature);
    }
}

class PaymentService
{
    public static function driver(): PaymentDriver
    {
        return config('services.payments.driver') === 'razorpay'
            ? new RazorpayPaymentDriver()
            : new FakePaymentDriver();
    }

    /**
     * Create (or reuse) the payment row for an order and return the
     * provider order id the app uses to open the checkout.
     */
    public static function initiate(Order $order): Payment
    {
        $payment = Payment::firstOrCreate(
            ['order_id' => $order->id],
            ['amount_paise' => $order->fare_paise, 'status' => 'pending']
        );

        if (!$payment->razorpay_order_id) {
            $result = self::driver()->createOrder($order);
            $payment->update(['razorpay_order_id' => $result['provider_order_id']]);
        }

        return $payment->fresh();
    }
}
