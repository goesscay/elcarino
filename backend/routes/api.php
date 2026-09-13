<?php

use App\Http\Controllers\Api\Auth\AuthController;
use App\Http\Controllers\Api\Chat\ChatController;
use App\Http\Controllers\Api\Discovery\DiscoveryController;
use App\Http\Controllers\Api\Matches\MatchController;
use App\Http\Controllers\Api\Notifications\NotificationController;
use App\Http\Controllers\Api\Profile\InterestController;
use App\Http\Controllers\Api\Profile\PreferenceController;
use App\Http\Controllers\Api\Profile\ProfileController;
use App\Http\Controllers\Api\Profile\ProfilePhotoController;
use App\Http\Controllers\Api\Profile\PromptController;
use App\Http\Controllers\Api\Swipe\SwipeController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\UserDeviceController;
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
        Route::put('users/me/location', [UserController::class, 'updateLocation'])
            ->middleware('throttle:location-update');
        Route::get('users/me/devices', [UserDeviceController::class, 'index']);
        Route::post('users/me/devices', [UserDeviceController::class, 'store']);
        Route::delete('users/me/devices/{device}', [UserDeviceController::class, 'destroy']);

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

        Route::prefix('discovery')->group(function () {
            Route::get('feed', [DiscoveryController::class, 'feed'])->middleware('throttle:discovery-feed');
        });

        Route::post('swipes', [SwipeController::class, 'store'])->middleware('throttle:swipes');

        Route::prefix('matches')->group(function () {
            Route::get('/', [MatchController::class, 'index']);
            Route::get('{match}', [MatchController::class, 'show']);
            Route::delete('{match}', [MatchController::class, 'destroy']);
        });

        Route::prefix('chat')->group(function () {
            Route::get('conversations', [ChatController::class, 'index']);
            Route::get('conversations/{conversation}/messages', [ChatController::class, 'messages']);
            Route::post('conversations/{conversation}/messages', [ChatController::class, 'sendMessage'])
                ->middleware('throttle:chat-messages');
            Route::put('conversations/{conversation}/read', [ChatController::class, 'markRead']);
        });

        Route::prefix('notifications')->group(function () {
            Route::get('/', [NotificationController::class, 'index']);
            Route::put('read-all', [NotificationController::class, 'markAllRead']);
            Route::put('{notification}/read', [NotificationController::class, 'markRead']);
        });
    });
});
