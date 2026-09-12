<?php

use App\Http\Controllers\Api\Auth\AuthController;
use App\Http\Controllers\Api\Profile\InterestController;
use App\Http\Controllers\Api\Profile\PreferenceController;
use App\Http\Controllers\Api\Profile\ProfileController;
use App\Http\Controllers\Api\Profile\ProfilePhotoController;
use App\Http\Controllers\Api\Profile\PromptController;
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

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('users/me', [UserController::class, 'me']);

        Route::prefix('profiles')->group(function () {
            Route::get('me', [ProfileController::class, 'show']);
            Route::put('me', [ProfileController::class, 'update']);
            Route::post('me/photos', [ProfilePhotoController::class, 'store']);
            Route::put('me/photos/order', [ProfilePhotoController::class, 'order']);
            Route::delete('me/photos/{photo}', [ProfilePhotoController::class, 'destroy']);
        });

        Route::prefix('prompts')->group(function () {
            Route::get('/', [PromptController::class, 'index']);
            Route::get('me', [PromptController::class, 'mine']);
            Route::put('me', [PromptController::class, 'update']);
            Route::delete('me/{prompt}', [PromptController::class, 'destroy']);
        });

        Route::prefix('preferences')->group(function () {
            Route::get('me', [PreferenceController::class, 'show']);
            Route::put('me', [PreferenceController::class, 'update']);
        });

        Route::prefix('interests')->group(function () {
            Route::get('/', [InterestController::class, 'index']);
            Route::get('me', [InterestController::class, 'mine']);
            Route::put('me', [InterestController::class, 'update']);
        });
    });
});
