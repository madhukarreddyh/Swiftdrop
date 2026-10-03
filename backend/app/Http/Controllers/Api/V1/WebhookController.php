<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Payment;
use App\Services\PaymentService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class WebhookController extends Controller
{
    /**
     * POST /api/v1/webhooks/razorpay  (no auth — signature verified instead)
     * Marks the payment paid when Razorpay confirms it.
     */
    public function razorpay(Request $request)
    {
        $payload = $request->getContent();
        $signature = $request->header('X-Razorpay-Signature', '');

        if (!PaymentService::driver()->verifyWebhookSignature($payload, $signature)) {
            Log::warning('Razorpay webhook: bad signature.');
            return response()->json(['message' => 'Bad signature.'], 401);
        }

        $event = $request->input('event');
        $providerOrderId = $request->input('payload.payment.entity.order_id');

        if ($event === 'payment.captured' && $providerOrderId) {
            $payment = Payment::where('razorpay_order_id', $providerOrderId)->first();

            if ($payment && $payment->status !== 'paid') {
                $payment->update([
                    'status' => 'paid',
                    'razorpay_payment_id' => $request->input('payload.payment.entity.id'),
                    'signature_verified' => true,
                ]);
                $payment->order()->update(['payment_status' => 'paid']);
            }
        }

        return response()->json(['ok' => true]);
    }
}
