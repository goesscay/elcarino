<?php

namespace App\Http\Controllers\Api\Payments;

use App\Http\Controllers\Controller;
use App\Http\Resources\Payments\PaymentResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    /**
     * GET /api/v1/payments/history
     */
    public function history(Request $request): JsonResponse
    {
        $payments = $request->user()->payments()->latest()->get();

        return response()->json(['payments' => PaymentResource::collection($payments)]);
    }
}
