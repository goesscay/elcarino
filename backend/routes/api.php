<?php

use App\Http\Controllers\Api\Auth\AuthController;
use App\Http\Controllers\Api\UserController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::prefix('auth')->group(function () {
        Route::post('register', [AuthController::class, 'register'])->middleware('throttle:auth-write');
        Route::post('login', [AuthController::class, 'login'])->middleware('throttle:login');
        Route::post('otp/request', [AuthController::class, 'requestOtp'])->middleware('throttle:otp-request');
        Route::post('otp/verify', [AuthController::class, 'verifyOtp'])->middleware('throttle:otp-verify');
        Route::post('oauth/google', [AuthController::class, 'oauthGoogle'])->middleware('throttle:auth-write');
        Route::post('oauth/apple', [AuthController::class, 'oauthApple'])->middleware('throttle:auth-write');
        Route::post('password/forgot', [AuthController::class, 'forgotPassword'])->middleware('throttle:auth-write');
        Route::post('password/reset', [AuthController::class, 'resetPassword'])->middleware('throttle:auth-write');

        Route::middleware('auth:sanctum')->post('logout', [AuthController::class, 'logout']);
    });

    Route::middleware('auth:sanctum')->get('users/me', [UserController::class, 'me']);
});
